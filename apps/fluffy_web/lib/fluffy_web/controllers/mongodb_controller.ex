defmodule FluffyWeb.MongoDBController do
  require Logger
  alias FluffyWeb.ControllerHelpers
  alias WaterWeeds.MongoDBClient
  use FluffyWeb, :controller

  # Allowed records collections
  @allowed_collections ~w(
    Surveys SurveyWeedAgent Sites SiteInspections SiteInspectionWeeds Locations
    Districts Regions Continents Countries Implementers Programs WeedNames Users
    ControlAgents SurveyControlAgents WHMCounter WHMeasurements WHMeasurementReadings BAR
  )

  # Implement Jason.Encoder for BSON.ObjectId
  defimpl Jason.Encoder, for: BSON.ObjectId do
    def encode(value, opts) do
      Jason.Encode.string(BSON.ObjectId.encode!(value), opts)
    end
  end

  @spec all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def all(conn, %{"collection" => collection}) do
    # Ensure only allowed collections are queried
    if collection in @allowed_collections do
      documents = MongoDBClient.get_all_documents(collection)
      isAdmin = get_session(conn, :role) == "admin"

      conn
      |> put_status(:ok)
      |> json(%{isAdmin: isAdmin, documents: documents})
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Invalid collection"})
    end
  end

  def all(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing collection parameter"})
  end

  def search(conn, %{"search" => search_text} = params) do
    collection = Map.get(params, "collection", "Surveys")

    if collection in @allowed_collections do
      documents =
        if String.trim(search_text) == "" do
          MongoDBClient.get_all_documents(collection)
        else
          MongoDBClient.search_documents_by_text(collection, search_text)
        end

      isAdmin = get_session(conn, :role) == "admin"

      conn
      |> put_status(:ok)
      |> json(%{
        isAdmin: isAdmin,
        documents: documents
      })
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Invalid collection"})
    end
  end

  # Fetch a document by its ID
  def show(conn, %{"id" => id, "collection" => collection}) do
    collection = collection || "Surveys"

    with {:ok, bson_id} <- BSON.ObjectId.decode(id),
         doc when not is_nil(doc) <- MongoDBClient.get_document_by_id(collection, bson_id) do
      normalized = ControllerHelpers.normalize_mongo_id(doc)
      json(conn, normalized)
    else
      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid document ID"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Document not found"})
    end
  end

  # Fetch a document as HTML
  def show_html(conn, %{"id" => id} = params) do
    collection = Map.get(params, "collection", "Surveys")

    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        case MongoDBClient.get_document_by_id(collection, bson_id) do
          %{} = doc ->
            normalized = ControllerHelpers.normalize_mongo_id(doc)
            profile = get_session(conn, :profile)
            role = get_session(conn, :role)

            current_user_email =
              if profile do
                Map.get(profile, :email)
              else
                nil
              end

            owner_email = Map.get(normalized, "userLogin")

            can_edit =
              role == "admin" or
                (not is_nil(current_user_email) and current_user_email == owner_email)

            editing = params["edit"] == "true"

            oauth_url = ElixirAuthGoogle.generate_oauth_url(FluffyWeb.Endpoint.url())

            redirect_path =
              conn.request_path <>
                if conn.query_string != "" do
                  "?" <> conn.query_string
                else
                  ""
                end

            conn =
              put_session(
                conn,
                :redirect_after_login,
                redirect_path
              )

            cond do
              editing and is_nil(current_user_email) ->
                conn
                |> put_flash(:error, "You must be logged in to edit a document.")
                |> redirect(to: "/documents/#{id}?collection=#{collection}")

              editing and not can_edit ->
                conn
                |> put_status(:forbidden)
                |> put_flash(
                  :error,
                  "You are not authorised to edit this document."
                )
                |> redirect(to: "/documents/#{id}?collection=#{collection}")

              true ->
                template =
                  if editing do
                    :edit
                  else
                    :show
                  end

                render(
                  conn,
                  template,
                  document: normalized,
                  collection: collection,
                  profile: profile,
                  oauth_url: oauth_url,
                  can_edit: can_edit
                )
            end

          _ ->
            conn
            |> put_flash(:error, "Document not found")
            |> redirect(to: "/")
        end

      _ ->
        conn
        |> put_flash(:error, "Invalid document ID")
        |> redirect(to: "/")
    end
  end

  def get_image(conn, %{"id" => id}) do
    with {:ok, bson_id} <- BSON.ObjectId.decode(id),
         %{bucket: bucket} <- :sys.get_state(WaterWeeds.MongoDBClient),
         {{:ok, stream}, file_doc} <- Mongo.GridFs.Download.find_and_stream(bucket, bson_id) do
      content_type =
        case Path.extname(file_doc["filename"]) do
          ".jpg" -> "image/jpeg"
          ".jpeg" -> "image/jpeg"
          ".png" -> "image/png"
          ".gif" -> "image/gif"
          _ -> "application/octet-stream"
        end

      conn =
        conn
        |> put_resp_content_type(content_type)
        |> send_chunked(200)

      stream_chunks(conn, stream)
    else
      _ -> send_resp(conn, 404, "Image not found")
    end
  end

  def get_publication(conn, %{"id" => id}) do
    with {:ok, bson_id} <- BSON.ObjectId.decode(id),
         %{bucket: bucket} <- :sys.get_state(WaterWeeds.MongoDBClient),
         {{:ok, stream}, file_doc} <-
           Mongo.GridFs.Download.find_and_stream(bucket, bson_id) do
      content_type =
        case Path.extname(file_doc["filename"]) do
          ".pdf" ->
            "application/pdf"

          ".doc" ->
            "application/msword"

          ".docx" ->
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

          _ ->
            "application/octet-stream"
        end

      conn =
        conn
        |> put_resp_header(
          "content-disposition",
          ~s(inline; filename="#{file_doc["filename"]}")
        )
        |> put_resp_content_type(content_type)
        |> send_chunked(200)

      stream_chunks(conn, stream)
    else
      _ ->
        send_resp(conn, 404, "Publication not found")
    end
  end

  defp stream_chunks(conn, stream) do
    Enum.reduce_while(stream, conn, fn chunk, conn_acc ->
      case Plug.Conn.chunk(conn_acc, chunk) do
        {:ok, conn_acc} -> {:cont, conn_acc}
        {:error, _} -> {:halt, conn_acc}
      end
    end)
  end

  # Action to upload and process a CSV file with dynamic fields
  @spec upload_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def upload_csv(conn, %{"file" => %Plug.Upload{path: file_path}, "collection" => collection}) do
    # Ensure session is fetched before trying to get data from it
    conn = fetch_session(conn)

    profile = get_session(conn, :profile)
    email = profile && Map.get(profile, :email)

    # Validate collection name
    if collection not in @allowed_collections do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Invalid collection"})
    else
      if email do
        # Read and parse the CSV file safely
        csv_stream = File.stream!(file_path)

        # Check if the file is empty
        if Enum.empty?(csv_stream) do
          conn
          |> put_status(:bad_request)
          |> render("upload_empty.html", message: "CSV file is empty", collection: collection)
        else
          csv_data =
            file_path
            |> File.stream!()
            |> CSV.decode(separator: ?,, headers: true)
            |> Enum.map(fn
              {:ok, row} ->
                row
                |> ControllerHelpers.normalize_keys()
                # Add user email to each row
                |> Map.put("userLogin", email)
                |> Map.put("approved", false)
                |> Map.put("approved_by", nil)
                |> Map.put("approved_at", nil)
                |> ControllerHelpers.add_date_dt()
                |> ControllerHelpers.parse_location()

              {:error, reason} ->
                {:error, reason}
            end)

          # Filter out rows that failed to decode
          documents = Enum.filter(csv_data, &is_map/1)

          if documents == [] do
            conn
            |> put_status(:bad_request)
            |> json(%{error: "No valid data found in CSV"})
          else
            Logger.debug("Inserting documents into #{collection}: #{inspect(documents)}")

            # Insert the documents into MongoDB
            case MongoDBClient.insert_many_documents(collection, documents) do
              {:ok, result} ->
                _inserted_documents =
                  Enum.map(result.inserted_ids, fn bson_obj ->
                    MongoDBClient.get_document_by_id(collection, bson_obj)
                  end)
                  |> Enum.filter(&(&1 != nil))
                  |> Enum.map(&ControllerHelpers.normalize_mongo_id/1)

                conn
                |> put_status(:created)
                |> render("upload_success.html",
                  message: "Upload successful",
                  collection: collection
                )

              {:error, reason} ->
                Logger.error("Failed to insert CSV: #{inspect(reason)}")

                error_message =
                  case reason do
                    %Mongo.Error{message: message, code: code} -> %{message: message, code: code}
                    _ -> %{message: inspect(reason)}
                  end

                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Failed to create document", reason: error_message})
            end
          end
        end
      else
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated"})
      end
    end
  end

  def to_rhodes(conn, _params) do
    redirect(conn, external: "https://www.ru.ac.za/centreforbiologicalcontrol/")
  end

  def to_calendar(conn, _params) do
    redirect(conn,
      external:
        "https://calendar.google.com/calendar/embed?src=phelokazidube%40gmail.com&ctz=Africa%2FJohannesburg"
    )
  end

  # Function that approves the documents
  def approve(conn, %{"id" => id} = params) do
    role = get_session(conn, :role) || "user"
    profile = get_session(conn, :profile)
    admin_email = profile && Map.get(profile, :email)
    collection = Map.get(params, "collection", "Surveys")

    cond do
      collection not in @allowed_collections ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid collection"})

      role != "admin" or is_nil(admin_email) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only admins can approve documents"})

      true ->
        case BSON.ObjectId.decode(id) do
          {:ok, bson_id} ->
            update_fields = %{
              "approved" => true,
              "approved_by" => admin_email,
              "approved_at" => System.os_time(:second)
            }

            case MongoDBClient.update_document(
                   collection,
                   bson_id,
                   update_fields
                 ) do
              {:ok, updated_doc} ->
                document = ControllerHelpers.normalize_mongo_id(updated_doc)

                conn
                |> put_status(:ok)
                |> json(%{
                  message: "Document approved successfully",
                  document: document
                })

              {:error, reason} ->
                Logger.error("Failed to approve document: #{inspect(reason)}")

                conn
                |> put_status(:unprocessable_entity)
                |> json(%{
                  error: "Failed to approve document",
                  reason: inspect(reason)
                })
            end

          :error ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Invalid ID format"})
        end
    end
  end

  # Safer update_document
  def update_document(conn, %{"id" => id, "collection" => collection} = params) do
    role = get_session(conn, :role)
    profile = get_session(conn, :profile)

    current_user_email =
      if profile do
        Map.get(profile, :email)
      else
        nil
      end

    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        case MongoDBClient.get_document_by_id(collection, bson_id) do
          nil ->
            conn
            |> put_flash(:error, "Document not found")
            |> redirect(to: "/")

          %{} = existing_document ->
            owner_email = Map.get(existing_document, "userLogin")

            can_edit =
              role == "admin" or
                (not is_nil(current_user_email) and
                   current_user_email == owner_email)

            if can_edit do
              update_fields =
                params
                |> Map.drop([
                  "_csrf_token",
                  "_method",
                  "id",
                  "collection",
                  "userLogin",
                  "approved",
                  "approved_by",
                  "approved_at",
                  "created_at",
                  "_id"
                ])
                |> ControllerHelpers.add_date_dt()
                |> ControllerHelpers.parse_location()
                |> Map.merge(%{
                  "approved" => false,
                  "approved_by" => nil,
                  "approved_at" => nil,
                  "updated_by" => current_user_email,
                  "updated_at" => System.os_time(:second)
                })

              case MongoDBClient.update_document(collection, bson_id, update_fields) do
                {:ok, _updated_document} ->
                  conn
                  |> put_flash(
                    :info,
                    "Document updated successfully. It is awaiting re-approval."
                  )
                  |> redirect(to: ~p"/documents/#{id}?collection=#{collection}")

                {:error, reason} ->
                  Logger.error("Failed to update document: #{inspect(reason)}")

                  conn
                  |> put_flash(
                    :error,
                    "Failed to update document."
                  )
                  |> redirect(to: ~p"/documents/#{id}?collection=#{collection}&edit=true")
              end
            else
              conn
              |> put_status(:forbidden)
              |> put_flash(
                :error,
                "You are not authorised to edit this document."
              )
              |> redirect(to: ~p"/documents/#{id}?collection=#{collection}")
            end
        end

      :error ->
        conn
        |> put_flash(:error, "Invalid document ID")
        |> redirect(to: "/")
    end
  end

  # Function to fetch unapproved documents
  def unapproved(conn, _params) do
    documents = MongoDBClient.get_all_documents("Surveys", %{"approved" => false})

    # Return the documents as JSON
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  # Function to fetch approved documents
  def approved(conn, _params) do
    documents = MongoDBClient.get_all_documents("Surveys", %{"approved" => true})

    # Return the documents as JSON
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  @spec export_search_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def export_search_csv(conn, params) do
    search = Map.get(params, "search", "")
    collection = Map.get(params, "collection", "Surveys")

    if collection in @allowed_collections do
      csv = WaterWeeds.MongoDBClient.export(collection, search)

      filename =
        collection
        |> String.downcase()
        |> Kernel.<>(".csv")

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="#{filename}")
      )
      |> send_resp(200, csv)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Invalid collection"})
    end
  end
end
