defmodule WaterWeeds.MongoDBClient do
  require Logger
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:water_weeds, :mongodb_driver)

    case Mongo.start_link(url: config[:url], pool_size: config[:pool_size] || 5) do
      {:ok, conn} ->
        # Initialize the GridFS Bucket
        result = Mongo.GridFs.Bucket.new(conn, name: "fs", chunk_size: 261_120)

        # Log the result to see what it contains
        Logger.info("GridFS Bucket initialization result: #{inspect(result)}")

        # Now just return the bucket if it's a valid struct
        if is_map(result) and Map.has_key?(result, :topology_pid) do
          Logger.info("Connected to MongoDB and initialized GridFS Bucket successfully")
          {:ok, %{conn: conn, bucket: result}}
        else
          Logger.error("Failed to initialize GridFS Bucket with error: #{inspect(result)}")
          {:stop, {:error, "Failed to initialize GridFS Bucket"}}
        end

      {:error, reason} ->
        Logger.error("Failed to connect to MongoDB: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # Function to get all documents from a collection
  def get_all_documents(collection_name) do
    GenServer.call(__MODULE__, {:get_all_documents, collection_name})
  end

  # Function to search documents by text
  def search_documents_by_text(collection_name, search_text) do
    GenServer.call(__MODULE__, {:search_documents_by_text, collection_name, search_text})
  end

  # Function to insert a document into a collection
  @spec insert_document(String.t(), map()) :: {:ok, Mongo.InsertOneResult.t()} | {:error, any()}
  def insert_document(collection_name, document) do
    GenServer.call(__MODULE__, {:insert_document, collection_name, document})
  end

  # Function to get a document by its ID from a collection
  def get_document_by_id(collection_name, bson_id) do
    GenServer.call(__MODULE__, {:get_document_by_id, collection_name, bson_id})
  end

  #  Function to update a document by its ID
  def update_document(collection_name, bson_id, update_fields) do
    GenServer.call(__MODULE__, {:update_document, collection_name, bson_id, update_fields})
  end

  # Function to insert multiple documents into a collection (for CSV data)
  @spec insert_many_documents(String.t(), [map()]) ::
          {:ok, Mongo.InsertManyResult.t()} | {:error, any()}
  def insert_many_documents(collection_name, documents) do
    GenServer.call(__MODULE__, {:insert_many_documents, collection_name, documents})
  end

  ### Public Functions for GridFS ###

  # Upload an image to GridFS
  @spec upload_image(String.t(), binary(), map() | nil, BSON.ObjectId.t() | nil) ::
          {:ok, BSON.ObjectId.t()} | {:error, any()}
  def upload_image(filename, binary_data, metadata \\ nil, file_id \\ nil) do
    GenServer.call(__MODULE__, {:upload_image, filename, binary_data, metadata, file_id})
  end

  # Retrieve an image from GridFS
  @spec get_image(BSON.ObjectId.t() | String.t() | map()) ::
          {:ok, binary()} | {:error, any()}
  def get_image(file_id) do
    GenServer.call(__MODULE__, {:get_image, file_id})
  end

  # Update an image in GridFS
  @spec update_image(BSON.ObjectId.t(), binary()) :: {:ok, BSON.ObjectId.t()} | {:error, any()}
  def update_image(file_id, new_binary_data) do
    GenServer.call(__MODULE__, {:update_image, file_id, new_binary_data})
  end

  ### GenServer Callbacks ###
  def handle_call(
        {:upload_image, filename, binary_data, metadata, file_id},
        _from,
        %{bucket: bucket} = state
      ) do
    # Open an upload stream
    upload_stream = Mongo.GridFs.Upload.open_upload_stream(bucket, filename, metadata, file_id)

    # Stream the binary data into the upload stream
    Stream.resource(
      # Start with binary_data and an offset of 0
      fn -> {binary_data, 0} end,
      fn
        {remaining_data, offset} when byte_size(remaining_data) > 0 ->
          # Determine the chunk size (adjust to your needs, e.g., 4KB)
          # Example: 4 KB per chunk
          chunk_size = 4_096
          # Get the chunk from offset
          chunk = binary_part(remaining_data, 0, chunk_size)
          new_offset = offset + byte_size(chunk)
          # Return the chunk and the new remaining data with updated offset
          {[chunk], {remaining_data, new_offset}}

        _ ->
          # End the stream when no data is left
          {:halt, nil}
      end,
      fn _ -> :ok end
    )
    |> Stream.into(upload_stream)
    |> Stream.run()

    {:reply, {:ok, upload_stream.id}, state}
  end

  def handle_call({:get_image, file_id}, _from, %{bucket: bucket} = state) do
    case Mongo.GridFs.Download.open_download_stream(bucket, file_id) do
      {:ok, stream} ->
        binary_data = Enum.to_list(stream) |> IO.iodata_to_binary()
        {:reply, {:ok, binary_data}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:update_image, file_id, new_binary_data}, _from, %{bucket: bucket} = state) do
    # Delete the existing file by its ID
    case Mongo.GridFs.Bucket.delete(bucket, file_id) do
      {:ok, _delete_result} ->
        # Open an upload stream to re-upload the new binary data
        upload_stream =
          Mongo.GridFs.Upload.open_upload_stream(bucket, "updated_image", nil, file_id)

        try do
          # Stream the new binary data into the upload stream
          Stream.resource(
            fn -> new_binary_data end,
            fn
              <<>> -> {:halt, nil}
              chunk -> {[chunk], String.slice(new_binary_data, byte_size(chunk)..-1)}
            end,
            fn _ -> :ok end
          )
          |> Stream.into(upload_stream)
          |> Stream.run()

          {:reply, {:ok, upload_stream.id}, state}
        rescue
          e ->
            {:reply, {:error, e}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_all_documents, collection_name}, _from, %{conn: conn} = state) do
    # Fetch documents from the collection
    cursor = Mongo.find(conn, collection_name, %{})

    # Convert the cursor to a list and return it
    documents = cursor |> Enum.to_list()
    {:reply, documents, state}
  end

  def handle_call(
        {:search_documents_by_text, collection_name, search_text},
        _from,
        %{conn: conn} = state
      ) do
    # Define the filter for the text search
    filter = %{"$text" => %{"$search" => search_text}}

    # Fetch documents that match the text search
    cursor = Mongo.find(conn, collection_name, filter)

    # Convert the cursor to a list and return it
    documents = cursor |> Enum.to_list()
    {:reply, documents, state}
  end

  def handle_call({:insert_document, collection_name, document}, _from, %{conn: conn} = state) do
    # Insert document into the collection
    case Mongo.insert_one(conn, collection_name, document) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_document_by_id, collection_name, bson_id}, _from, %{conn: conn} = state) do
    # Fetch the document by its BSON ObjectId
    doc = Mongo.find_one(conn, collection_name, %{_id: bson_id})

    # Reply with the found document or nil
    {:reply, doc, state}
  end

  def handle_call(
        {:update_document, collection_name, bson_id, update_fields},
        _from,
        %{conn: conn} = state
      ) do
    # Using find_one_and_update to update the document
    update = %{"$set" => update_fields}

    case Mongo.find_one_and_update(
           conn,
           collection_name,
           %{_id: bson_id},
           update,
           return_document: :after
         ) do
      {:ok, doc} ->
        {:reply, {:ok, doc}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:insert_many_documents, collection_name, documents},
        _from,
        %{conn: conn} = state
      ) do
    # Insert multiple documents into the collection
    case Mongo.insert_many(conn, collection_name, documents) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
