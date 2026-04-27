defmodule FluffyWeb.MongoDBController do
  require Logger
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

  # Function to normalize the MongoDB _id to id
  def normalize_mongo_id(doc) do
    doc
    # Add the "id" field with the string version of BSON _id
    |> Map.put("id", BSON.ObjectId.encode!(doc["_id"]))
    # Remove the original "_id" field
    |> Map.delete("_id")
  end

  # Converts almost any header string (e.g. COUNTRY_ID, DataACCESSID) into clean camelCase.
  def to_camel_case(key) when is_binary(key) do
    key =
      key
      |> String.trim()
      |> String.replace(~r/[^a-zA-Z0-9\s%]/, " ")  # keep % for detection but remove other special chars

    words =
      key
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&String.downcase/1)

    # If header contains a percent sign or the word "percent", treat it specially
    is_percent =
      String.contains?(key, "%") or Enum.any?(words, &(&1 == "percent"))

    # Remove "percent" or "%" from the words list before camelizing
    cleaned_words =
      words
      |> Enum.reject(&(&1 in ["percent", "%"]))

    # Convert to camelCase
    camel =
      case cleaned_words do
        [] -> ""
        [first | rest] ->
          first <> Enum.map_join(rest, "", &String.capitalize/1)
      end
    if is_percent do
      "percent" <> String.capitalize(camel)
    else
      camel
    end
  end

  # Converts all map keys to camelCase safely
  def normalize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} ->
      new_key = to_camel_case(to_string(key))
      {new_key, value}
    end)
    |> Enum.into(%{})
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


  def search(conn, %{"search" => search_text}) do
    # Set the collection to "Surveys"
    collection = "Surveys"

    # Fetch documents that match the search text from the "Surveys" collection
    documents = MongoDBClient.search_documents_by_text(collection, search_text)
    isAdmin = get_session(conn, :role) == "admin"

    # Return the documents as JSON in the HTTP response
    conn
    |> put_status(:ok)
    |> json(%{isAdmin: isAdmin, documents: documents})
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    Logger.info("Received survey submission with params: #{inspect(Map.keys(params))}")

    profile = get_session(conn, :profile)
    email = if profile, do: Map.get(profile, :email), else: get_session(conn, :email)
    photos = Map.get(params, "photos", [])

    Logger.info("Photos param: #{inspect(Map.get(params, "photos"))}")

    # --- Handle uploaded photos ---
    processed_photos =
      photos
      |> Enum.map(fn
        %Plug.Upload{path: path, filename: filename, content_type: content_type} ->
          case File.read(path) do
            {:ok, binary_data} ->
              Logger.debug("Uploading photo #{filename} to GridFS")
              case MongoDBClient.upload_image(filename, binary_data, %{content_type: content_type}) do
                {:ok, file_id} -> BSON.ObjectId.encode!(file_id)
                {:error, reason} ->
                  Logger.error("Upload failed for #{filename}: #{inspect(reason)}")
                  nil
              end

            {:error, reason} ->
              Logger.error("Failed to read photo #{filename}: #{inspect(reason)}")
              nil
          end

        _ -> nil
      end)
      |> Enum.filter(& &1)

    # --- Clean up unwanted form fields ---
    cleaned_params =
      params
      |> Map.delete("_csrf_token")
      |> Map.delete("photos")

    # --- Define default structure ---
    default_values = %{
      "location" => "",
      "userLogin" => email,
      "controlAgent" => "",
      "targetWeedName" => "",
      "targetWeedRank" => "",
      "targetWeedId" => "",
      "targetWeedTaxonName" => "",
      "weather" => "",
      "water" => "",
      "photos" => processed_photos,
      "province" => "",
      "sitename" => "PMB Botanical Gardens",
      "date" => "",
      "noLeaves" => "",
      "noStems" => "",
      "noFlowers" => "",
      "noCapsules" => "",
      "maxHeight" => "",
      "noRamets" => "",
      "sizeOfInf" => "",
      "percentCover" => "",
      "description" => "",
      "approved" => false,
      "approved_by" => nil,
      "approved_at" => nil,
      "created_at" => System.os_time(:second)
    }

    # --- Merge defaults with form params ---
    document = Map.merge(default_values, cleaned_params)

    # --- Convert date string to machine-friendly Date ---
    document =
      case parse_date_string(Map.get(document, "date")) do
        nil -> Map.put(document, "date_dt", nil)
        date -> Map.put(document, "date_dt", date)
      end
      |> parse_location()

    # --- Insert into MongoDB ---
    case MongoDBClient.insert_document("Surveys", document) do
      {:ok, %{inserted_id: bson_id}} ->
        conn
        |> put_status(:created)
        |> json(%{
          message: "Survey document created successfully",
          id: BSON.ObjectId.encode!(bson_id)
        })

      {:error, reason} ->
        Logger.error("Failed to insert survey: #{inspect(reason)}")
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create document", reason: inspect(reason)})
    end
  end

  # Fetch a document by its ID
  def show(conn, %{"id" => id, "collection" => collection}) do
    collection = collection || "Surveys"

    with {:ok, bson_id} <- BSON.ObjectId.decode(id),
        doc when not is_nil(doc) <- MongoDBClient.get_document_by_id(collection, bson_id) do
      normalized = normalize_mongo_id(doc)
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
            normalized = normalize_mongo_id(doc)
            template = if params["edit"] == "true", do: :edit, else: :show
            oauth_url = ElixirAuthGoogle.generate_oauth_url(FluffyWeb.Endpoint.url())
            profile = get_session(conn, :profile)

            redirect_path =
              conn.request_path <>
                if conn.query_string != "" do
                  "?" <> conn.query_string
                else
                  ""
                end

            conn = put_session(conn, :redirect_after_login, redirect_path)

            render(conn, template,
              document: normalized,
              collection: collection,
              profile: profile,
              oauth_url: oauth_url
            )

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

      conn = conn
      |> put_resp_content_type(content_type)
      |> send_chunked(200)

      Enum.reduce_while(stream, conn, fn chunk, conn ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> {:cont, conn}
          {:error, _} -> {:halt, conn}
        end
      end)
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
          ".pdf" -> "application/pdf"
          ".doc" -> "application/msword"
          ".docx" ->
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          _ -> "application/octet-stream"
        end

      conn =
        conn
        |> put_resp_header(
          "content-disposition",
          ~s(inline; filename="#{file_doc["filename"]}")
        )
        |> put_resp_content_type(content_type)
        |> send_chunked(200)

      Enum.reduce_while(stream, conn, fn chunk, conn ->
        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> {:cont, conn}
          {:error, _} -> {:halt, conn}
        end
      end)
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
                |> normalize_keys()
                |> Map.put("userLogin", email)  # Add user email to each row
                |> add_date_dt()
                |> parse_location()

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
                  |> Enum.map(&normalize_mongo_id/1)

                conn
                |> put_status(:created)
                |> render("upload_success.html", message: "Upload successful", collection: collection)

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

  def add_date_dt(document) do
    date_str = Map.get(document, "date")
    year_str = Map.get(document, "year")

    parsed =
      cond do
        not is_nil(parse_date_string(date_str)) -> parse_date_string(date_str)
        not is_nil(parse_date_string(year_str)) -> parse_date_string(year_str)
        true -> nil
      end
    Map.put(document, "date_dt", parsed)
  end

  def parse_date_string(date_str) when is_binary(date_str) do
    cond do
      # Full date: MM/DD/YYYY
      Regex.match?(~r/^\d{2}\/\d{2}\/\d{4}$/, date_str) ->
        case Date.from_iso8601(convert_mmddyyyy_to_iso(date_str)) do
          {:ok, date} -> date
          _ -> nil
        end

      # Year-only: YYYY
      Regex.match?(~r/^\d{4}$/, date_str) ->
        case Date.from_iso8601("#{date_str}-01-01") do
          {:ok, date} -> date
          _ -> nil
        end

      true ->
        nil
    end
  end

  # Fallback for unrecognized formats
  def parse_date_string(_), do: nil

  def convert_mmddyyyy_to_iso(<<m1::binary-size(2), "/", d1::binary-size(2), "/", y1::binary-size(4)>>) do
    "#{y1}-#{m1}-#{d1}"
  end

  def parse_location(document) do
    lat = Map.get(document, "latitude") || Map.get(document, "Latitude")
    lon = Map.get(document, "longitude") || Map.get(document, "Longitude")

    cond do
      # Case 1: CSV headers exist
      is_binary(lat) or is_binary(lon) ->
        if lat != "" and lon != "" do
          case {Float.parse(lat), Float.parse(lon)} do
            {{lat_f, ""}, {lon_f, ""}} ->
              document
              |> Map.put("location", %{
                "type" => "Point",
                "coordinates" => [lon_f, lat_f]
              })
              |> Map.drop(["latitude", "Latitude", "longitude", "Longitude"])

            _ ->
              Map.put(document, "location", nil)
          end
        else
          Map.put(document, "location", nil)
        end

      # Case 2: Form field "location" = "lat, lon"
      is_binary(Map.get(document, "location")) ->
        case String.split(document["location"], ",", trim: true) do
          [lat_s, lon_s] ->
            case {Float.parse(String.trim(lat_s)), Float.parse(String.trim(lon_s))} do
              {{lat_f, ""}, {lon_f, ""}} ->
                Map.put(document, "location", %{
                  "type" => "Point",
                  "coordinates" => [lon_f, lat_f]
                })

              _ ->
                Map.put(document, "location", nil)
            end

          _ ->
            Map.put(document, "location", nil)
        end

      # Default: neither CSV nor Form → still enforce consistency
      true ->
        Map.put(document, "location", nil)
    end
  end

  def to_rhodes(conn, _params) do
    redirect(conn, external: "https://www.ru.ac.za/centreforbiologicalcontrol/")
  end

  def to_calendar(conn, _params) do
    redirect(conn, external: "https://calendar.google.com/calendar/embed?src=phelokazidube%40gmail.com&ctz=Africa%2FJohannesburg")
  end

  # Function that approves the documents
  def approve(conn, %{"id" => id}) do
    role = get_session(conn, :role) || "user"
    profile = get_session(conn, :profile)
    admin_email = profile && Map.get(profile, :email) # Get the email from profile
    IO.inspect(role, label: "Role in approve function")
    IO.inspect(admin_email, label: "Admin Email in approve function")

    if role == "admin" and admin_email do
      case BSON.ObjectId.decode(id) do
        {:ok, bson_id} ->
          IO.inspect(bson_id, label: "Decoded BSON ID")

          update_fields = %{
            "approved" => true,
            "approved_by" => admin_email, # Store admin's email
            "approved_at" => System.os_time(:second) # Timestamp of approval
          }

          case MongoDBClient.update_document("Surveys", bson_id, update_fields) do
            {:ok, _} ->
              # Fetch the updated document after approval
              case MongoDBClient.get_document_by_id("Surveys", bson_id) do
                {:ok, updated_doc} when not is_nil(updated_doc) ->
                  document = normalize_mongo_id(updated_doc)

                  conn
                  |> put_status(:ok)
                  |> json(%{message: "Document approved successfully", document: document})

                _ ->
                  conn
                  |> put_status(:ok)
                  |> json(%{message: "Document approved, but fetching updated document failed."})
              end

            {:error, reason} ->
              IO.inspect(reason, label: "MongoDB Update Error")

              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Failed to approve document", reason: reason})
          end

        {:error, reason} ->
          IO.inspect(reason, label: "Invalid BSON ID")

          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid ID format"})
      end
    else
      IO.puts("Approval denied: User is not admin or email missing")

      conn
      |> put_status(:forbidden)
      |> json(%{error: "Only admins can approve documents"})
    end
  end

  def update(conn, %{"id" => id, "updates" => updates}) do
    role = get_session(conn, :role) || "user"
    profile = get_session(conn, :profile)
    email = profile && Map.get(profile, :email)

    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        # Fetch the existing document first
        case MongoDBClient.get_document_by_id("Surveys", bson_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Document not found"})

          %{"userLogin" => user_login} ->
            # Check authorization: must be admin or document owner
            if role == "admin" or email == user_login do
              # Merge in the unapproval reset
              update_fields =
                updates
                |> Map.merge(%{
                  "approved" => false,
                  "approved_by" => nil,
                  "approved_at" => nil
                })

              case MongoDBClient.update_document("Surveys", bson_id, update_fields) do
                {:ok, _} ->
                  case MongoDBClient.get_document_by_id("Surveys", bson_id) do
                    {:ok, updated_doc} ->
                      document = normalize_mongo_id(updated_doc)

                      conn
                      |> put_status(:ok)
                      |> json(%{
                        message: "Document updated successfully and marked as unapproved",
                        document: document
                      })

                    _ ->
                      conn
                      |> put_status(:ok)
                      |> json(%{
                        message: "Document updated, but fetching updated document failed"
                      })
                  end

                {:error, reason} ->
                  conn
                  |> put_status(:unprocessable_entity)
                  |> json(%{error: "Failed to update document", reason: reason})
              end
            else
              conn
              |> put_status(:forbidden)
              |> json(%{
                error: "You are not authorized to edit this document"
              })
            end

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Error fetching document", reason: reason})
        end

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})
    end
  end

  # Safer update_document
  def update_document(conn, %{"id" => id, "collection" => collection} = params) do
    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        update_fields =
          params
          |> Map.drop(["_csrf_token", "_method", "id", "collection"])
          |> Map.put("approved", false)

        case MongoDBClient.update_document(collection, bson_id, update_fields) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Document updated successfully. Awaiting re-approval.")
            |> redirect(to: ~p"/documents/#{id}?collection=#{collection}")

          {:error, reason} ->
            conn
            |> put_flash(:error, "Failed to update document: #{inspect(reason)}")
            |> redirect(to: ~p"/documents/#{id}?collection=#{collection}&edit=true")
        end

      {:error, _} ->
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

 @excluded_fields ["photos", "approved_at", "approved_by"]

  # Export all documents as CSV
  def export_csv(conn, _params) do
    collection = "Surveys"

    documents =
      MongoDBClient.get_all_documents(collection)
      # |> Enum.map(&Normalizer.normalize/1)
      |> Enum.map(&Map.drop(&1, @excluded_fields))

    # csv = CSVBuilder.build(documents, @excluded_fields)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="surveys.csv"))
    # |> send_resp(200, csv)
  end

  @spec export_search_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def export_search_csv(conn, %{"search" => search}) do
    csv = WaterWeeds.MongoDBClient.export(search)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header(
      "content-disposition",
      ~s(attachment; filename="surveys_#{String.replace(search, " ", "_")}.csv")
    )
    |> send_resp(200, csv)
  end
end
