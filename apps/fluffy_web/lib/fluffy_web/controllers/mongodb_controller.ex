defmodule FluffyWeb.MongoDBController do
  alias WaterWeeds.MongoDBClient
  use FluffyWeb, :controller


  # Implement Jason.Encoder for BSON.ObjectId
  defimpl Jason.Encoder, for: BSON.ObjectId do
    def encode(value, opts) do
      Jason.Encode.string(BSON.ObjectId.encode!(value), opts)
    end
  end

  # Function to normalize the MongoDB _id to id
  defp normalize_mongo_id(doc) do
    doc
    |> Map.put("id", BSON.ObjectId.encode!(doc["_id"]))  # Add the "id" field with the string version of BSON _id
    |> Map.delete("_id")  # Remove the original "_id" field
  end

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

  def create(conn, _params) do
    default_values = %{
      "location" => "",
      "userLogin" => "",
      "controlAgent" => "",
      "targetWeedName" => "",
      "targetWeedRank" => "",
      "targetWeedId" => "",
      "targetWeedTaxonName" => "",
      "weather" => "",
      "water" => "",
      "photos" => "",
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
      "approved" => false,  # Field marks the document as unapproved initially
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
      |> CSV.decode(separator: ?,, headers: true) # Use comma as the delimiter and read headers dynamically
      |> Enum.map(fn
        {:ok, row} -> row
        {:error, reason} -> {:error, reason} # Handle any errors in CSV decoding
      end)

    # Filter out any rows that had errors
    documents = Enum.filter(csv_data, fn item -> is_map(item) end)

    # Insert the documents into MongoDB
    case MongoDBClient.insert_many_documents("Sana", documents) do
      {:ok, result} ->
        # Fetch inserted documents by their BSON ObjectIds and normalize _id to id
        inserted_documents =
          Enum.map(result.inserted_ids, fn bson_obj ->
            MongoDBClient.get_document_by_id("Sana", bson_obj)
          end)
          |> Enum.filter(&(&1 != nil))     # Filter out any nil results
          |> Enum.map(&normalize_mongo_id/1) # Normalize BSON _id to id

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

  def approve(conn, %{"id" => id}) do
    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        # Update the "approved" field to true
        case MongoDBClient.update_document("Surveys", bson_id, %{"approved" => true}) do
          {:ok, doc} ->
            document = normalize_mongo_id(doc)
            conn
            |> put_status(:ok)
            |> json(%{message: "Document approved successfully", document: document})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to approve document", reason: reason})
        end

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})
    end
  end

  def unapproved(conn, _params) do
    # Fetch unapproved documents from the "Surveys" collection
    documents = MongoDBClient.get_all_documents("Surveys", %{"approved" => false})

    # Return the documents as JSON
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  # Function to fetch approved documents
  def approved(conn, _params) do
    # Fetch approved documents from the "Surveys" collection
    documents = MongoDBClient.get_all_documents("Surveys", %{"approved" => true})

    # Return the documents as JSON
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  # def approve(conn, %{"id" => id}) do
  #   case MongoDBClient.approve_document("Surveys", id) do
  #     {:ok, _result} ->
  #       conn
  #       |> put_status(:ok)
  #       |> json(%{message: "Document approved successfully"})

  #     {:error, reason} ->
  #       conn
  #       |> put_status(:unprocessable_entity)
  #       |> json(%{error: "Failed to approve document", reason: reason})
  #   end
  # end
end
