defmodule WaterWeeds.MongoDBClient do
  require Logger
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:water_weeds, :mongodb_driver)

    # Use Mongo.start_link/1 to connect to the MongoDB database
    case Mongo.start_link(url: config[:url], pool_size: config[:pool_size] || 5) do
      {:ok, conn} ->
        # Log successful connection and initialize state with the connection
        Logger.info("Connected to MongoDB successfully")
        {:ok, %{conn: conn}}

      {:error, reason} ->
        # Log error and stop the GenServer
        Logger.error("Failed to connect to MongoDB: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # Function to get all documents from a collection
   # Function to get all documents from a collection (default filter: %{})
  def get_all_documents(collection_name) do
    get_all_documents(collection_name, %{})
  end

  # Function to get all documents from a collection with a filter
  def get_all_documents(collection_name, filter) do
    GenServer.call(__MODULE__, {:get_all_documents, collection_name, filter})
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
  @spec insert_many_documents(String.t(), [map()]) :: {:ok, Mongo.InsertManyResult.t()} | {:error, any()}
  def insert_many_documents(collection_name, documents) do
    GenServer.call(__MODULE__, {:insert_many_documents, collection_name, documents})
  end

    # Handle call for getting documents with a filter
    def handle_call({:get_all_documents, collection_name, filter}, _from, %{conn: conn} = state) do
      # Fetch documents from the collection with the given filter
      cursor = Mongo.find(conn, collection_name, filter)
      documents = cursor |> Enum.to_list()
      {:reply, documents, state}
    end

  def handle_call({:search_documents_by_text, collection_name, search_text}, _from, %{conn: conn} = state) do
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

  def handle_call({:update_document, collection_name, bson_id, update_fields}, _from, %{conn: conn} = state) do
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

  def handle_call({:insert_many_documents, collection_name, documents}, _from, %{conn: conn} = state) do
    # Insert multiple documents into the collection
    case Mongo.insert_many(conn, collection_name, documents) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Approve a specific document by updating the "approved" field
  def approve_document(collection, document_id) do
    # Convert the document_id to BSON ObjectId
    object_id = BSON.ObjectId.decode!(document_id)

    # Update the document by setting "approved" to true
    Mongo.update_one(:mongo, collection, %{"_id" => object_id}, %{"$set" => %{"approved" => true}})
  end
end
