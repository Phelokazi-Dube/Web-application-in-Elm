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

  def to_camel_case(key) when is_binary(key) do
    key
    |> String.replace(~r/[^a-zA-Z0-9\s]/, "")  # Remove non-alphanumeric chars (e.g., ".", "%")
    |> String.split()                          # Split words by spaces
    |> Enum.map(&Macro.camelize/1)             # Convert each word to PascalCase
    |> then(fn [first | rest] ->
      String.downcase(first) <> Enum.join(rest, "")
    end)
  end

  def normalize_keys(map) do
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

  def create(conn, %{"photos" => photos} = _params) do
    # Fetch the authenticated user's email from the session
    email = get_session(conn, :email)

    # If the email exists, proceed with adding it to the default values
    if email do
      # Process uploaded photos using GridFS
      processed_photos =
        photos
        |> Enum.map(fn %Plug.Upload{path: file_path, filename: filename} ->
          case File.read(file_path) do
            {:ok, binary_data} ->
              # Log the metadata being passed to the upload function
              Logger.debug(
                "Uploading image with metadata: #{inspect(%{content_type: "image/png"})}"
              )

              # Upload image with the correct metadata
              case MongoDBClient.upload_image(filename, binary_data, %{content_type: "image/png"}) do
                {:ok, file_id} ->
                  # Return the ObjectId of the uploaded image (as a BSON ID)
                  BSON.ObjectId.encode!(file_id)

                {:error, reason} ->
                  Logger.error("Failed to upload photo: #{inspect(reason)}")
                  nil
              end

            {:error, reason} ->
              Logger.error("Failed to read photo file: #{inspect(reason)}")
              nil
          end
        end)
        # Exclude failed uploads (nil values)
        |> Enum.filter(&(&1 != nil))

      # Default values for the document to be inserted into the "Surveys" collection
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

      # Insert the document into the "Surveys" collection
      case MongoDBClient.insert_document("Surveys", default_values) do
        {:ok, %{inserted_id: bson_id}} ->
          # Fetch the inserted document to return
          case MongoDBClient.get_document_by_id("Surveys", bson_id) do
            nil ->
              conn
              |> put_status(:not_found)
              |> json(%{error: "Document not found after insertion"})

            {:ok, doc} ->
              document =
                normalize_mongo_id(doc)
                |> Jason.encode!()

              conn
              |> put_status(:created)
              |> json(%{message: "Document created successfully", document: document})

            {:error, _} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Failed to fetch created document"})
          end

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to create document", reason: reason})
      end
    else
      # If the email is not found in the session, return an unauthorized error
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "User not authenticated"})
    end
  end

  # Fetch a document by its ID
  def show(conn, %{"id" => id}) do
    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        # Fetch the document from the "Surveys" collection by its ID
        doc = MongoDBClient.get_document_by_id("Surveys", bson_id)

        case doc do
          nil ->
            send_resp(conn, 404, "Not Found")

          %{} ->
            # Normalize the document by replacing _id with id
            document =
              normalize_mongo_id(doc)
              |> Jason.encode!()

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, document)

          {:error, _} ->
            send_resp(conn, 500, "Something went wrong")
        end

      {:error, _reason} ->
        send_resp(conn, 400, "Invalid ID format")
    end
  end

  def show_html(conn, %{"id" => id, "collection" => collection}) do
    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        case MongoDBClient.get_document_by_id(collection, bson_id) do
          nil ->
            conn
            |> put_flash(:error, "Document not found")
            |> redirect(to: "/")

          %{} = doc ->
            normalized = normalize_mongo_id(doc)
            render(conn, :show, document: normalized)

          {:error, _} ->
            conn
            |> put_flash(:error, "Could not retrieve document")
            |> redirect(to: "/")
        end

      {:error, _reason} ->
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
        # Read and parse the CSV file
        csv_data =
          file_path
          |> File.stream!()
          |> CSV.decode(separator: ?,, headers: true)
          |> Enum.map(fn
            {:ok, row} ->
              row
              |> normalize_keys()
              |> Map.put("userLogin", email)  # Add user email to each row

            {:error, reason} ->
              {:error, reason}
          end)

        # Filter out rows that failed to decode
        documents = Enum.filter(csv_data, &is_map/1)

        # Insert the documents into MongoDB
        case MongoDBClient.insert_many_documents(collection, documents) do
          {:ok, result} ->
            inserted_documents =
              Enum.map(result.inserted_ids, fn bson_obj ->
                MongoDBClient.get_document_by_id(collection, bson_obj)
              end)
              |> Enum.filter(&(&1 != nil))
              |> Enum.map(&normalize_mongo_id/1)

            conn
            |> put_status(:created)
            |> render("upload_success.html", message: "Upload successful")

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to insert CSV data", reason: reason})
        end
      else
        # If not logged in, reject the upload
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
end
