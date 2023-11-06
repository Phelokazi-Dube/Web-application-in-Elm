defmodule Fluffy.CouchDBClient do
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

  def create(id, value) do
    GenServer.call(__MODULE__, {:create, id, value})
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
    IO.inspect(state.server)
    {:reply, :couchdb_server.all_dbs(state.server), state}
  end

  def handle_call({:all_docs, db, options}, _from, state) do
    {:reply, :couchdb_documents.get(state.conn, db, options),  state}
  end

  def handle_call({:create, id, value}, _from, state) do
    {:reply, :couchdb_documents.save(state.conn, %{"_id" => id, "value" => value}), state}
  end
end
