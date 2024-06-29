defmodule Fluffy.CouchDBClient do
  require Logger
  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    config = Application.get_env(:fluffy, :couchdb)
    with  server <- :couchbeam.server_connection(config[:host], config[:port], "", [basic_auth: {config[:user], config[:pass]}]),
          {:ok, db} <- :couchbeam.open_db(server, config[:db_name]) do
      # After initialization, return a map that contains the server and the connection.
      # This map will always be passed to the handle_call/3 function as the last argument.
      {:ok, %{db: db} }
    end
  end

  def get_document(id) do
    GenServer.call(__MODULE__, {:get_document, id})
  end

  def all_docs() do
    GenServer.call(__MODULE__, :all_docs)
  end

  def uuid() do
    GenServer.call(__MODULE__, :uuid)
  end

  def create(value) do
    with {:ok, id} <- uuid() do
      GenServer.call(__MODULE__, {:create, id, value})
    else
      _ -> {:error, "Could not create get a UUID for document"}
    end
  end

  def create(id, value) do
    # IO.inspect(value)
    # IO.inspect(id)
    GenServer.call(__MODULE__, {:create, id, value})
  end

  def search(query) do
    GenServer.call(__MODULE__, {:search, query})
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

  # def search(db, query, options \\ []) do
  #   headers = Keyword.put_new(options, :accept, "application/json")
  #   GenServer.call(__MODULE__, {:search, db, query, headers})
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

  def handle_call(:uuid, _from, state) do
    with  {_, server, _, _} <- state.db,
          {_, host, _} <- server,
          url <- :hackney_url.make_url(host, "/_uuids", [count: 1]),
          {:ok, 200, _, ref} <- :couchbeam_httpc.request(:get, url, [], "", []),
          {:ok, body} <- :hackney.body(ref),
          %{"uuids" => [uuid]} <- :couchbeam_ejson.decode(body) do
            {:reply, {:ok, uuid}, state}
          else
            _ -> {:reply, {:error, "Could not get UUID"}, state}
          end
    # docId = :couchbeam.get_uuid(server)
  end

  def handle_call({:get_document, id}, _from, state) do
    {:reply, :couchbeam.open_doc(state.db, id) |> Mapper.map_open_resp, state}
  end

  def handle_call(:all_docs, _from, state) do
    {:reply, :couchbeam_view.all(state.db), state}
  end

  def handle_call({:search, query}, _from, state) do
    {_, {_, host, _}, _, _} = state.db
    # replace these with the correct ones!
    db = "cbctryout"
    design_doc = "_design/yolo"
    index_name = "wassup"
    url = :hackney_url.make_url(host, [db, design_doc, "_search", index_name], [q: query])
    case :couchbeam_httpc.db_request(:get, url, [], [], [], [200]) do
      {:ok, _, _, ref} ->
          {:ok, body} = :hackney.body(ref)
          %{"rows" => rows} = body |> :couchbeam_ejson.decode()
          ids = Enum.map(rows, &Map.get(&1, "id"))
          docs =
            (Enum.map(ids, &:couchbeam.open_doc(state.db, &1))
            |> Enum.filter(fn {code, _} -> code == :ok end))
            |> Enum.map(fn {:ok, doc} -> doc end)
          {:reply, {:ok, docs}, state}
      {:error, reason} ->
        Logger.error(reason)
        {:reply, {:error, reason}, state}
    end
  end
  # def handle_call({:search, db, query, options}, _from, state) do
  #   {:reply, :couchdb_mango.find(state.conn, db, query, options), state}
  # end

  def handle_call({:create, id, value}, _from, state) do
    {_, {_, host, _}, _, _} = state.db
    url = :hackney_url.make_url(host, :couchbeam_httpc.doc_url(state.db, id), [])
    # Check if any of the values is a %Plug.Upload.  If it is, put it into a separate map.
    # We will need to save it as an attachment separately.
    { uploads, fields } =
      # How do I identify a file upload?
      # Either it's a single Plug.Upload struct, OR it's a list of Plug.Upload structs.
      # So, check for either of these.
      Map.split_with(value, fn {_k, v} -> is_struct(v, Plug.Upload) or (is_list(v) and not(Enum.empty?(v)) and Enum.all?(v, &is_struct(&1, Plug.Upload))) end)
    dbValue = Mapper.map_to_list(Map.put(fields, "_id", id))
    if map_size(uploads) > 0 do
      boundary = :couchbeam_uuids.random()
      # IO.puts("Testing 123")
      items =
        uploads
        |> Map.to_list()
        |> Enum.map(fn {k, v} -> Enum.map(v, fn upload -> Map.put(Map.from_struct(upload), :field, k) end) end)
        |> Enum.concat()
        |> Enum.map(fn upload -> {"#{upload.field}_#{upload.filename}", File.read!(upload.path), upload.content_type, "identity"} end)
      {len, jsondoc, doc2} = :couchbeam_httpc.len_doc_to_mp_stream(items, boundary, {dbValue})
      headers = [{"Content-Type", "multipart/related; boundary=\"#{boundary}\""}, {"Content-Length", to_string(len)}]
      case :couchbeam_httpc.request(:put, url, headers, :stream, []) do
        {:ok, ref} ->
          result = :couchbeam_httpc.send_mp_doc(items, ref, boundary, jsondoc, doc2)
          IO.inspect(result)
          {:reply, result, state}
        {:error, reason} ->
          Logger.warning("Error while creating a new document: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      json = :couchbeam_ejson.encode(dbValue)
      case :couchbeam_httpc.db_request(:put, url, [{"Content-Type", "application/json"}], json, [], [200, 201, 202]) do
        {:ok, 201, _, ref} ->
          {:ok, body} = :hackney.body(ref)
          %{"id" => id} = :couchbeam_ejson.decode(body)
          {:reply, {:ok, id}, state}
        {:ok, status, _, ref} ->
          {:ok, body} = :hackney.body(ref)
          Logger.warning("Error (incorrect status #{status}) while creating a new document: #{inspect(body)}")
          {:reply, {:error, body}, state}
        {:error, reason} ->
          Logger.warning("Error while creating a new document: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

end



# this is just stuff extracted from CouchEx
defmodule Mapper do

  def list_to_map([]), do: []
  def list_to_map({:error, err_msg}), do: {:error, err_msg}
  def list_to_map([ { hd } | _tail] = list) when is_list(hd) do
    list |> Enum.map(&list_to_map(&1))
  end
  def list_to_map({list}) when is_list(list) do
    list_to_map(list)
  end
  def list_to_map([ hd | _tail] = tuple_list) when is_tuple(hd)  do
    tuple_list |> Enum.reduce(%{}, fn(pair, acc)-> tuple_to_map(pair, acc) end)
  end

  defp tuple_to_map({list}, _map) when is_list(list),do: list_to_map(list)
  defp tuple_to_map({k,v}, map) when is_tuple(v),   do: map |> Map.put(k, tuple_to_map(v, %{}))
  defp tuple_to_map({k,v}, map),                    do: map |> Map.put(k, parse_value(v))

  defp parse_value(v) when is_list(v),  do: v |> Enum.map(fn(val)-> parse_value(val) end)
  defp parse_value(v) when is_tuple(v), do: tuple_to_map(v, %{})
  defp parse_value(v),                  do: v

  def map_to_list({k,v}),                   do: [{k, v}]
  def map_to_list(map) when is_map(map),    do: reduce(map)
  def map_to_list(list) when is_list(list), do: list |> Enum.map(fn(v)-> map_to_list(v) end)
  def map_to_list(v) when is_atom(v),       do: v
  def map_to_list(v) when is_binary(v),     do: v
  def map_to_list(v) when is_number(v),     do: v
  def map_to_list(v) when is_boolean(v),    do: v
  def map_to_list([]),                      do: []


  def map_response({:ok, [{list}]}) when is_list(list), do: {:ok, Enum.into(list, %{})}
  def map_response(list) when is_list(list) do
    res = list |> Enum.map(fn(t)->
        {l} = t
        Enum.into(l, %{})
      end)
    {:ok, res}
  end
  def map_response({:ok, _status_code, resp, _ref}), do: {:ok, Enum.into(resp, %{})}
  def map_response({:ok, {response}}), do: {:ok, response |> Enum.into(%{})}
  def map_response({:error, response}), do: {:error, response}
  def map_response(response), do: {:ok, response}

  def map_open_resp({:error, err}), do: {:error, err}
  def map_open_resp({:ok, resp}),   do: resp |> list_to_map

  def reduce(map) do
    map |> Enum.reduce([], fn({k,v}, acc) -> [{k, map_to_list(v)}] ++ acc end)
  end
end


# {:ok, env} = Fluffy.CouchDBClient.init(9)
# to_store = %{"hello" => "world", "this" => "is me", "_id" => "BRINDLE"}
# in_fmt = Mapper.map_to_list(to_store)
## :couchbeam.save_doc(env.db, {in_fmt}, [], [])
# {_, server, _, _} = env.db
# url = :hackney_url.make_url("http://localhost:5984", "/_uuids", [count: 1])
# {:ok, 200, _, ref} = :couchbeam_httpc.request(:get, url, [], "", [])
# {:ok, body} = :hackney.body(ref)
# docId = :couchbeam.get_uuid(server)
