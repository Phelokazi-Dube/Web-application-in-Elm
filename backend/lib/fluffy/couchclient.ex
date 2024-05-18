defmodule Fluffy.CouchDBClient do
  require Logger
  use GenServer
  alias :couchbeam, as: CouchDB

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:fluffy, :couchdb)
    with  server <- CouchDB.server_connection(config[:host], config[:port], "", [basic_auth: {config[:user], config[:pass]}]),
          {:ok, db} <- CouchDB.open_db(server, config[:db_name]) do
      # After initialization, return a map that contains the server and the connection.
      # This map will always be passed to the handle_call/3 function as the last argument.
      {:ok, %{db: db} }
    end
  end

  def get_document(id) do
    GenServer.call(__MODULE__, {:get_document, id})
  end

  @spec all_docs(any()) :: any()
  def all_docs() do
    GenServer.call(__MODULE__, :all_docs)
  end

  def create(value) do
    GenServer.call(__MODULE__, {:create, value})
  end

  def create(id, value) do
    # IO.inspect(value)
    # IO.inspect(id)
    GenServer.call(__MODULE__, {:create, id, value})
  end

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

  # # Each handle_call/3 function returns a tuple with three elements:
  # #   - The first element is the kind of result that you're getting.  This can be one of
  # #     - :reply, for sending information back to the caller
  # #     - :noreply, if nothing needs to be sent back to the caller
  # #     - :stop, if the GenServer needs to stop (e.g. shutting down)
  # # (But let's only look at the :reply case, for the rest of this comment)
  # #   - The second element is the value that will be returned to the caller
  # #   - The third element is the new state of the GenServer.  USUALLY, we'll continue with the
  # #     same state that we received, but sometimes we'll need to update the state.

  def handle_call({:get_document, id}, _from, state) do
    {:reply, :couchbeam.open_doc(state.db, id), state}
  end

  def handle_call(:all_docs, _from, state) do
    {:reply, :couchbeam_view.all(state.db), state}
  end

  def handle_call({:create, id, value}, _from, state) do
    dbValue = Map.put(value, "_id", id)
    {:reply, :couchdb_documents.save(state.conn, dbValue), state}
  end

  # def handle_call({:search, db, query, options}, _from, state) do
  #   {:reply, :couchdb_mango.find(state.conn, db, query, options), state}
  # end

  def handle_call({:create, value}, _from, state) do
    # Check if any of the values is a %Plug.Upload.  If it is, put it into a separate map.
    # We will need to save it as an attachment separately.
    { uploads, fields } =
      # How do I identify a file upload?
      # Either it's a single Plug.Upload struct, OR it's a list of Plug.Upload structs.
      # So, check for either of these.
      Map.split_with(value, fn {_k, v} -> is_struct(v, Plug.Upload) or (is_list(v) and not(Enum.empty?(v)) and Enum.all?(v, &is_struct(&1, Plug.Upload))) end)
    attachments =
      if map_size(uploads) == 0 do
        Map.values(uploads)
        |> Enum.map(fn upload -> {upload.filename, File.read!(upload.path), upload.content_type, "identity"} end)
        |> IO.inspect()
      else
        []
      end
    case :couchbeam.save_doc(state.db, fields, attachments, []) do
      {:ok, doc} ->
        {:reply, Map.get(doc, "_id"), state}
      {:error, reason} ->
        Logger.warning("Error while creating a new document: #{inspect(reason)}")
        {:reply, :error, state}
    end
  end
end
