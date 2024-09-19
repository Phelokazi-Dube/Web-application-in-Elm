defmodule Fluffy.CouchDBClient do
  require Logger
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:fluffy, :mongodb_driver)

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
  def get_all_documents(collection_name) do
    GenServer.call(__MODULE__, {:get_all_documents, collection_name})
  end

  def handle_call({:get_all_documents, collection_name}, _from, %{conn: conn} = state) do
    # Fetch documents from the collection
    cursor = Mongo.find(conn, collection_name, %{})

    # Convert the cursor to a list and return it
    documents = cursor |> Enum.to_list()
    {:reply, documents, state}
  end

  # Function to search documents by text
  def search_documents_by_text(collection_name, search_text) do
    GenServer.call(__MODULE__, {:search_documents_by_text, collection_name, search_text})
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

  # Function to insert a document into a collection
  @spec insert_document(String.t(), map()) :: {:ok, Mongo.InsertOneResult.t()} | {:error, any()}
  def insert_document(collection_name, document) do
    GenServer.call(__MODULE__, {:insert_document, collection_name, document})
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

  # Function to get a document by its ID from a collection
  def get_document_by_id(collection_name, bson_id) do
    GenServer.call(__MODULE__, {:get_document_by_id, collection_name, bson_id})
  end

  def handle_call({:get_document_by_id, collection_name, bson_id}, _from, %{conn: conn} = state) do
    # Fetch the document by its BSON ObjectId
    doc = Mongo.find_one(conn, collection_name, %{_id: bson_id})

    # Reply with the found document or nil
    {:reply, doc, state}
  end

  #  Function to update a document by its ID
  def update_document(collection_name, bson_id, update_fields) do
    GenServer.call(__MODULE__, {:update_document, collection_name, bson_id, update_fields})
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

  # def get_document(id) do
  #   GenServer.call(__MODULE__, {:get_document, id})
  # end

  # def all_documents(db, options \\ []) do
  #   GenServer.call(__MODULE__, {:all_documents, db, options})
  # end

  # def all_dbs() do
  #   GenServer.call(__MODULE__, :all_dbs)
  # end

  # def all_docs(db, options) do
  #   headers = Keyword.put_new(options, :accept, "application/json")
  #   GenServer.call(__MODULE__, {:all_docs, db, headers})
  # end

  # def create(value) do
  #   GenServer.call(__MODULE__, {:create, value})
  # end

  # def create(id, value) do
  #   # IO.inspect(value)
  #   # IO.inspect(id)
  #   GenServer.call(__MODULE__, {:create, id, value})
  # end

  # def search(db, query, options \\ []) do
  #   headers = Keyword.put_new(options, :accept, "application/json")
  #   GenServer.call(__MODULE__, {:search, db, query, headers})
  # end

  # # This function is called by the handle_call/3 function when it needs to save an attachment.
  # def save_attachment!(db, upload, doc) do
  #   case :couchdb_attachments.put(db, doc, upload.filename, File.read!(upload.path), content_type: upload.content_type) do
  #     {:ok, new_doc} ->
  #       Logger.debug("Attachment saved: #{upload.filename} (#{upload.content_type})")
  #       new_doc
  #     {:error, reason} ->
  #       Logger.warning("I could not save attachment #{upload.filename} to document #{Map.get(doc, "_id")}: #{reason}")
  #       raise reason
  #   end
  # end

  # def get_attachment(db, doc_id, attachment_name) do
  #   GenServer.call(__MODULE__, {:get_attachment, db, doc_id, attachment_name})
  # end

  # Each handle_call/3 function returns a tuple with three elements:
  #   - The first element is the kind of result that you're getting.  This can be one of
  #     - :reply, for sending information back to the caller
  #     - :noreply, if nothing needs to be sent back to the caller
  #     - :stop, if the GenServer needs to stop (e.g. shutting down)
  # (But let's only look at the :reply case, for the rest of this comment)
  #   - The second element is the value that will be returned to the caller
  #   - The third element is the new state of the GenServer.  USUALLY, we'll continue with the
  #     same state that we received, but sometimes we'll need to update the state.

  # Handling getting documents by ID
  # def handle_call({:get_document, id}, _from, state) do
  #   {:reply, :couchdb_documents.get(state.conn, id), state}
  # end

  # Handling getting all the documents
  # def handle_call({:all_documents, db, options}, _from, %{conn: conn} = state) do
  #   options = Enum.into(options, %{}, fn {k, v} -> {String.to_atom(k), v} end)

  #   result = :couchdb_databases.all_docs(conn, options)
  #   {:reply, result, state}
  # end

  # Handling getting all the databases
  # def handle_call(:all_dbs, _from, state) do
  #   # IO.inspect(state.server)
  #   {:reply, :couchdb_server.all_dbs(state.server), state}
  # end

  # def handle_call({:all_docs, db, options}, _from, state) do
  #   {:reply, :couchdb_documents.get(state.conn, db, options), state}
  # end

  # Handle creating a document
  # def handle_call({:create, id, value}, _from, state) do
  #   dbValue = Map.put(value, "_id", id)
  #   {:reply, :couchdb_documents.save(state.conn, dbValue), state}
  # end

  # # Handle searching for a document by using a text
  # def handle_call({:search, db, query, options}, _from, state) do
  #   {:reply, :couchdb_mango.find(state.conn, db, query, options), state}
  # end

  # def handle_call({:get_attachment, db, doc_id, attachment_name}, _from, %{conn: conn} = state) do
  #   result = :couchdb_attachments.get(conn, doc_id, attachment_name)
  #   {:reply, result, state}
  # end

  # Handle and attachment to a document
  # def handle_call({:create, value}, _from, state) do
  #   # Check if any of the values is a %Plug.Upload.  If it is, put it into a separate map.
  #   # We will need to save it as an attachment separately.
  #   { uploads, fields } =
  #     # How do I identify a file upload?
  #     # Either it's a single Plug.Upload struct, OR it's a list of Plug.Upload structs.
  #     # So, check for either of these.
  #     Map.split_with(value, fn {_k, v} -> is_struct(v, Plug.Upload) or (is_list(v) and not(Enum.empty?(v)) and Enum.all?(v, &is_struct(&1, Plug.Upload))) end)
  #   case :couchdb_documents.save(state.conn, fields) do
  #     {:ok, doc} ->
  #       # If there are any uploads, save them as attachments.
  #       if map_size(uploads) == 0 do
  #         {:reply, Map.get(doc, "_id"), state}
  #       else
  #         # If there are any uploads, save them as attachments.
  #         # If the value is a list, then we have multiple uploads for the same field.
  #         # We need to save each one separately.
  #         final_doc =
  #           Map.values(uploads) # get a list of the values in the map
  #           # Every time that I upload an attachment, a new document revision is created.
  #           # At the end, I need to specify the latest document revision as the return value.
  #           # A "foldl" (i.e. fold-from-the-left) lets me do all of these things concisely and efficiently.
  #           |> List.foldl(doc,
  #             fn (v, doc) ->
  #               if is_list(v) do
  #                 # Every time that I upload an attachment, I must specify the LATEST document to upload it to.
  #                 # Therefore, as I process each attachment, I must obtain the latest document revision
  #                 # for use with the next attachment.
  #                 List.foldl(v, doc, &save_attachment!(state.conn, &1, &2))
  #               else
  #                 save_attachment!(state.conn, v, doc)
  #               end
  #             end)
  #         {:reply, Map.get(final_doc, "_id"), state}
  #       end
  #     {:error, reason} ->
  #       Logger.warning("Error while creating a new document: #{inspect(reason)}")
  #       {:reply, :error, state}
  #   end
  # end
end
