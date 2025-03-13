defmodule FluffyWeb.MongoDBController do
  require Logger
  alias WaterWeeds.MongoDBClient
  use FluffyWeb, :controller

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
  def all(conn, _params) do
    # Fetch all documents from the "Surveys" collection
    documents = MongoDBClient.get_all_documents("Surveys")

    # Return the documents as JSON in the HTTP response
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  def search(conn, %{"search" => search_text}) do
    # Set the collection to "Surveys"
    collection = "Surveys"

    # Fetch documents that match the search text from the "Surveys" collection
    documents = MongoDBClient.search_documents_by_text(collection, search_text)

    # Return the documents as JSON in the HTTP response
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
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
        # List of processed photo IDs
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
        "description" => "💝",
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

  # Action to upload and process a CSV file with dynamic fields
  def upload_csv(conn, %{"file" => %Plug.Upload{path: file_path}}) do
    # Read the CSV file and decode it with dynamic headers (headers: true)
    csv_data =
      file_path
      |> File.stream!()
      # Use comma as the delimiter and read headers dynamically
      |> CSV.decode(separator: ?,, headers: true)
      |> Enum.map(fn
        {:ok, row} ->  normalize_keys(row)  # Convert CSV headers to camelCase
        # Handle any errors in CSV decoding
        {:error, reason} -> {:error, reason}
      end)

    # Filter out any rows that had errors
    documents = Enum.filter(csv_data, &is_map/1)

    # Insert the documents into MongoDB
    case MongoDBClient.insert_many_documents("Surveys", documents) do
      {:ok, result} ->
        # Fetch inserted documents by their BSON ObjectIds and normalize _id to id
        inserted_documents =
          Enum.map(result.inserted_ids, fn bson_obj ->
            MongoDBClient.get_document_by_id("Surveys", bson_obj)
          end)
          # Filter out any nil results
          |> Enum.filter(&(&1 != nil))
          # Normalize BSON _id to id
          |> Enum.map(&normalize_mongo_id/1)

        conn
        |> put_status(:created)
        |> json(%{message: "CSV data inserted successfully", documents: inserted_documents})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to insert CSV data", reason: reason})
    end
  end

  def to_rhodes(conn, _params) do
    redirect(conn, external: "https://www.ru.ac.za/centreforbiologicalcontrol/")
  end

  def to_calender(conn, _params) do
    redirect(conn, external: "https://calendar.google.com/calendar/embed?src=phelokazidube%40gmail.com&ctz=Africa%2FJohannesburg")
  end
end
