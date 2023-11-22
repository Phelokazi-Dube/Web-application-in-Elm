defmodule FluffyWeb.CouchDBController do
  alias Fluffy.CouchDBClient
  use FluffyWeb, :controller



  def show(conn, %{"id" => id}) do
    with  {:ok, value} <- CouchDBClient.get_document(id) |> IO.inspect() do
      conn
      |> put_status(:ok)
      |> json(%{message: "OK", value: value})
    else
      {:error, :unauthenticated} ->
        conn
        |> put_status(:unauthorized)
        # |> json(%{problem: "Unauthenticated", solution: "Permit unauthenticated localhost access to CouchDB?  Or figure out the permissions..."})
      {:error, :not_found} ->
        default_values =  %{
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
          "description" => ""
        }
        CouchDBClient.create(id, default_values)
        conn
        |> put_status(:ok)
        |> json(%{message: "OK", value: "NEW value created in CouchDB; refresh and I'll show it to you"})
    end
    # {:ok, parsed_doc} = Jiffy.decode(doc)
    # conn
    # |> put_status(:ok)
    # |> json(%{message: "OK", doc: doc})
  end


  def find(conn, _) do
    case CouchDBClient.all_dbs() do
      {:ok, databases} ->
        conn
        |> put_status(:ok)
        |> json(databases)

      {:error, :unauthenticated} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{"error" => "Unauthenticated.  Probable fix: in Fauxton, go to Configuration options; under the \"chttpd\" section, add the option \"admin_only_all_dbs\" and set it to the value: false"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{"error" => "List of databases not found"})

      {:error, :http_error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{"error" => "Error while fetching the list of databases from CouchDB"})
    end
  end

  def fetch_documents(conn, %{"db_name" => db_name}) do
    options = [include_docs: true, accept: "application/json"]

    with {:ok, documents} <- CouchDBClient.all_docs(db_name, options) do
      conn
      |> put_status(:ok)
      |> json(%{message: "OK", documents: documents})
    else
      {:error, reason} ->
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: "Error while fetching documents from CouchDB: #{reason}"})
    end
  end
end
