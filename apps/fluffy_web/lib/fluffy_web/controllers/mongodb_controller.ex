defmodule FluffyWeb.MongoDBController do
  require Logger
  alias FluffyWeb.ControllerHelpers
  alias WaterWeeds.MongoDBClient
  use FluffyWeb, :controller

  # Collections recognised by FluffyWeb
  @allowed_collections ~w(
    Surveys SurveyWeedAgent Sites SiteInspections SiteInspectionWeeds Locations
    Districts Regions Continents Countries Implementers Programs WeedNames Users
    ControlAgents SurveyControlAgents WHMCounter WHMeasurements WHMeasurementReadings BAR
  )

  # Collections that must not be exposed through public API endpoints
  @private_collections ~w(
    Users
    Implementers
    WHMCounter
  )

  # Stable identities used to prevent duplicate records during CSV uploads.
  # Collections are included only where a safe identity has been established.
  @csv_identities %{
    "Surveys" => ["surveyId"],
    "SurveyWeedAgent" => ["swaid"],
    "SiteInspections" => ["siteInspectionId"],
    "SiteInspectionWeeds" => ["siteInspectionWeedId"],
    "Locations" => ["locationId"],
    "Districts" => ["districtId"],
    "Regions" => ["regionId"],
    "Continents" => ["continentId"],
    "Countries" => ["countryId", "continentId"],
    "Implementers" => ["implementerId"],
    "WeedNames" => ["weedId"],
    "ControlAgents" => ["controlAgentId"],
    "SurveyControlAgents" => ["id"],
    "WHMeasurements" => ["whmid"],
    "BAR" => ["barId"]
  }

  defp validate_collection_access(conn, collection) do
    cond do
      collection not in @allowed_collections ->
        {:error, :invalid_collection}

      collection in @private_collections and get_session(conn, :role) != "admin" ->
        {:error, :forbidden}

      true ->
        :ok
    end
  end

  defp collection_access_error(conn, :invalid_collection) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid collection"})
  end

  defp collection_access_error(conn, :forbidden) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "You are not authorized to access this collection"})
  end

  # Implement Jason.Encoder for BSON.ObjectId
  defimpl Jason.Encoder, for: BSON.ObjectId do
    def encode(value, opts) do
      Jason.Encode.string(BSON.ObjectId.encode!(value), opts)
    end
  end

  @spec all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def all(conn, %{"collection" => collection}) do
    # Ensure only allowed collections are queried
    case validate_collection_access(conn, collection) do
      :ok ->
          documents = MongoDBClient.get_all_documents(collection)
          isAdmin = get_session(conn, :role) == "admin"

          conn
          |> put_status(:ok)
          |> json(%{isAdmin: isAdmin, documents: documents})
      end
  end

  def all(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing collection parameter"})
  end

  def search(conn, %{"search" => search_text} = params) do
    collection = Map.get(params, "collection", "Surveys")

    case validate_collection_access(conn, collection) do
    :ok ->
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

      {:error, reason} ->
        collection_access_error(conn, reason)
    end
  end

  # Fetch a document by its ID
  def show(conn, %{"id" => id, "collection" => collection}) do
    collection = collection || "Surveys"

    case validate_collection_access(conn, collection) do
      :ok ->
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

      {:error, reason} ->
        collection_access_error(conn, reason)
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
                  document_id: id,
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
    conn = fetch_session(conn)
    profile = get_session(conn, :profile)
    email = profile && Map.get(profile, :email)

    cond do
      collection not in @allowed_collections ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid collection"})

      is_nil(email) ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated"})

      not Map.has_key?(@csv_identities, collection) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error:
            "CSV upload is not available for #{collection} because a safe record identity has not been configured."
        })

      true ->
        process_csv_upload(conn, file_path, collection, email)
    end
  end

  defp process_csv_upload(conn, file_path, collection, email) do
    if File.stat!(file_path).size == 0 do
      conn
      |> put_status(:bad_request)
      |> render("upload_empty.html",
        message: "CSV file is empty",
        collection: collection
      )
    else
      documents =
        file_path
        |> File.stream!()
        |> CSV.decode(separator: ?,, headers: true)
        |> Enum.flat_map(fn
          {:ok, row} ->
            document =
              row
              |> ControllerHelpers.normalize_keys()
              |> Map.put("userLogin", email)
              |> Map.put("approved", false)
              |> Map.put("approved_by", nil)
              |> Map.put("approved_at", nil)
              |> ControllerHelpers.add_date_dt()
              |> ControllerHelpers.parse_location()

            [document]

          {:error, reason} ->
            Logger.warning("Skipping invalid CSV row: #{inspect(reason)}")
            []
        end)

      if documents == [] do
        conn
        |> put_status(:bad_request)
        |> json(%{error: "No valid data found in CSV"})
      else
        upsert_csv_documents(conn, collection, documents)
      end
    end
  end

  defp upsert_csv_documents(conn, collection, documents) do
    identity_fields = Map.fetch!(@csv_identities, collection)

    case validate_csv_identities(documents, identity_fields) do
      :ok ->
        case perform_csv_upserts(collection, documents, identity_fields) do
          {:ok, processed_count} ->
            Logger.info(
              "Processed #{processed_count} CSV documents for #{collection}"
            )

            conn
            |> put_status(:created)
            |> render("upload_success.html",
              message: "Upload successful",
              collection: collection,
              processed_count: processed_count
            )

          {:error, reason} ->
            Logger.error("Failed to process CSV: #{inspect(reason)}")

            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to process CSV",
              reason: inspect(reason)
            })
        end

      {:error, missing_fields} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("upload_error.html",
          title: "CSV Does Not Match This Collection",
          message:
            "This file does not appear to contain the required fields for #{collection}. Please check that you selected the correct CSV file.",
          collection: collection,
          required_fields: identity_fields,
          missing_fields: missing_fields
        )
    end
  end

  defp validate_csv_identities(documents, identity_fields) do
    missing_fields =
      documents
      |> Enum.flat_map(fn document ->
        Enum.filter(identity_fields, fn field ->
          value = Map.get(document, field)

          is_nil(value) or
            (is_binary(value) and String.trim(value) == "")
        end)
      end)
      |> Enum.uniq()

    case missing_fields do
      [] -> :ok
      fields -> {:error, fields}
    end
  end

  defp perform_csv_upserts(collection, documents, identity_fields) do
    Enum.reduce_while(documents, {:ok, 0}, fn document, {:ok, count} ->
      filter = Map.take(document, identity_fields)

      case MongoDBClient.upsert_document(collection, filter, document) do
        {:ok, _result} ->
          {:cont, {:ok, count + 1}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  def delete_document(conn, %{"id" => id, "collection" => collection}) do
    role = get_session(conn, :role)
    profile = get_session(conn, :profile)

    current_user_email =
      if profile do
        Map.get(profile, :email)
      else
        nil
      end

    case validate_collection_access(conn, collection) do
      :ok ->
        case BSON.ObjectId.decode(id) do
          {:ok, bson_id} ->
            case MongoDBClient.get_document_by_id(collection, bson_id) do
              nil ->
                conn
                |> put_flash(:error, "Document not found.")
                |> redirect(to: "/records")

              %{} = existing_document ->
                owner_email = Map.get(existing_document, "userLogin")

                can_delete =
                  role == "admin" or
                    (not is_nil(current_user_email) and
                      current_user_email == owner_email)

                if can_delete do
                  case MongoDBClient.delete_document(collection, bson_id) do
                    {:ok, _result} ->
                      conn
                      |> put_flash(:info, "Document deleted successfully.")
                      |> redirect(to: "/records")

                    {:error, reason} ->
                      Logger.error(
                        "Failed to delete document #{id} from #{collection}: #{inspect(reason)}"
                      )

                      conn
                      |> put_flash(:error, "Failed to delete document.")
                      |> redirect(to: "/documents/#{id}?collection=#{collection}")
                  end
                else
                  conn
                  |> put_status(:forbidden)
                  |> put_flash(
                    :error,
                    "You are not authorised to delete this document."
                  )
                  |> redirect(to: "/documents/#{id}?collection=#{collection}")
                end
            end

          :error ->
            conn
            |> put_flash(:error, "Invalid document ID.")
            |> redirect(to: "/records")
        end

      {:error, reason} ->
        collection_access_error(conn, reason)
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

  def to_annual_reports(conn, _params) do
    redirect(conn,
      external: "https://www.ru.ac.za/centreforbiologicalcontrol/resources/annualreports"
    )
  end

  def to_publications(conn, _params) do
    redirect(conn,
      external: "https://www.ru.ac.za/centreforbiologicalcontrol/resources/publications"
    )
  end

  def to_news(conn, _params) do
    redirect(conn,
      external: "https://www.ru.ac.za/centreforbiologicalcontrol/latestnews"
    )
  end

  def to_facebook(conn, _params) do
    redirect(conn,
      external: "https://www.facebook.com/RhodesUniCBC"
    )
  end

  def to_linkedin(conn, _params) do
    redirect(conn,
      external: "https://www.linkedin.com/company/centre-for-biological-control"
    )
  end

  def to_instagram(conn, _params) do
    redirect(conn,
      external: "https://www.instagram.com/rhodesunicbc"
    )
  end

  def to_x(conn, _params) do
    redirect(conn,
      external: "https://x.com/RhodesUniCBC"
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

    case validate_collection_access(conn, collection) do
    :ok ->
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

   {:error, reason} ->
      collection_access_error(conn, reason)
  end
  end
end
