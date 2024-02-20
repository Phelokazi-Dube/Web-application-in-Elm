defmodule Fluffy.CouchDBClient do
  require Logger
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:fluffy, :couchdb)
    url = "http://#{config[:server]}" |> IO.inspect
    with  {:ok, server} <- :couchdb.server_record(url, username: config[:user], password: config[:pass]) |> IO.inspect,
          {:ok, connection} <- :couchdb.database_record(server, config[:db_name]) |> IO.inspect do
      # After initialization, return a map that contains the server and the connection.
      # This map will always be passed to the handle_call/3 function as the last argument.
      {:ok, %{server: server, conn: connection} }
    end
  end

  def get_document(id) do
    GenServer.call(__MODULE__, {:get_document, id})
  end

  def all_dbs() do
    GenServer.call(__MODULE__, :all_dbs)
  end

  def all_docs(db, options) do
    headers = Keyword.put_new(options, :accept, "application/json")
    GenServer.call(__MODULE__, {:all_docs, db, headers})
  end

  def create(value) do
    GenServer.call(__MODULE__, {:create, value})
  end

  def create(id, value) do
    # IO.inspect(value)
    # IO.inspect(id)
    GenServer.call(__MODULE__, {:create, id, value})
  end

  # This function is called by the handle_call/3 function when it needs to save an attachment.
  def save_attachment!(db, upload, doc) do
    case :couchdb_attachments.put(db, doc, upload.filename, File.read!(upload.path), content_type: upload.content_type) do
      {:ok, new_doc} ->
        Logger.debug("Attachment saved: #{upload.filename} (#{upload.content_type})")
        new_doc
      {:error, reason} ->
        Logger.warning("I could not save attachment #{upload.filename} to document #{Map.get(doc, "_id")}: #{reason}")
        raise reason
    end
  end

  # Each handle_call/3 function returns a tuple with three elements:
  #   - The first element is the kind of result that you're getting.  This can be one of
  #     - :reply, for sending information back to the caller
  #     - :noreply, if nothing needs to be sent back to the caller
  #     - :stop, if the GenServer needs to stop (e.g. shutting down)
  # (But let's only look at the :reply case, for the rest of this comment)
  #   - The second element is the value that will be returned to the caller
  #   - The third element is the new state of the GenServer.  USUALLY, we'll continue with the
  #     same state that we received, but sometimes we'll need to update the state.

  def handle_call({:get_document, id}, _from, state) do
    {:reply, :couchdb_documents.get(state.conn, id), state}
  end

  def handle_call(:all_dbs, _from, state) do
    # IO.inspect(state.server)
    {:reply, :couchdb_server.all_dbs(state.server), state}
  end

  def handle_call({:all_docs, db, options}, _from, state) do
    {:reply, :couchdb_documents.get(state.conn, db, options), state}
  end

  def handle_call({:create, id, value}, _from, state) do
    dbValue = Map.put(value, "_id", id)
    {:reply, :couchdb_documents.save(state.conn, dbValue), state}
  end

  def handle_call({:create, value}, _from, state) do
    # Check if any of the values is a %Plug.Upload.  If it is, put it into a separate map.
    # We will need to save it as an attachment separately.
    { uploads, fields } =
      # How do I identify a file upload?
      # Either it's a single Plug.Upload struct, OR it's a list of Plug.Upload structs.
      # So, check for either of these.
      Map.split_with(value, fn {_k, v} -> is_struct(v, Plug.Upload) or (is_list(v) and not(Enum.empty?(v)) and Enum.all?(v, &is_struct(&1, Plug.Upload))) end)
    case :couchdb_documents.save(state.conn, fields) do
      {:ok, doc} ->
        # If there are any uploads, save them as attachments.
        if map_size(uploads) == 0 do
          {:reply, Map.get(doc, "_id"), state}
        else
          # If there are any uploads, save them as attachments.
          # If the value is a list, then we have multiple uploads for the same field.
          # We need to save each one separately.
          final_doc =
            Map.values(uploads) # get a list of the values in the map
            # Every time that I upload an attachment, a new document revision is created.
            # At the end, I need to specify the latest document revision as the return value.
            # A "foldl" (i.e. fold-from-the-left) lets me do all of these things concisely and efficiently.
            |> List.foldl(doc,
              fn (v, doc) ->
                if is_list(v) do
                  # Every time that I upload an attachment, I must specify the LATEST document to upload it to.
                  # Therefore, as I process each attachment, I must obtain the latest document revision
                  # for use with the next attachment.
                  List.foldl(v, doc, &save_attachment!(state.conn, &1, &2))
                else
                  save_attachment!(state.conn, v, doc)
                end
              end)
          {:reply, Map.get(final_doc, "_id"), state}
        end
      {:error, reason} ->
        Logger.warning("Error while creating a new document: #{inspect(reason)}")
        {:reply, :error, state}
    end
  end
end
