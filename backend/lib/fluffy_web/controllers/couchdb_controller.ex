defmodule FluffyWeb.CouchDBController do
  alias Fluffy.CouchDBClient
  use FluffyWeb, :controller



  def show(conn, %{"id" => id}) do
    with  {:ok, value} <- CouchDBClient.get_document(id) |> IO.inspect() do
      html_content = """
      <div style="max-width:100%; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 5px;">
        <h1 style="color: #333;">Document Info</h1>
        <p><strong>ID:</strong> #{value["_id"]}</p>
        <p><strong>Revision:</strong> #{value["_rev"]}</p>
        <p><strong>Created on:</strong> #{value["created_at"]}</p>
        <p><strong>Created by :</strong> #{value["userLogin"]}</p>

          <div style="margin-top: 20px; padding: 10px; border: 1px solid #ddd; border-radius: 5px;">
          <h2 style="color: #333;">Contents</h2>
          <p><strong>Location:</strong> #{value["location"]}</p>
          <p><strong>Observed on:</strong> #{value["date"]}</p>
          <p><strong>Control Agent:</strong> #{value["controlAgent"]}</p>
          <p><strong>Target Weed Name:</strong> #{value["targetWeedName"]}</p>
          <p><strong>Target Weed Rank:</strong> #{value["targetWeedRank"]}</p>
          <p><strong>Target Weed Taxon Name:</strong> #{value["targetWeedTaxonName"]}</p>
          <p><strong>Weather:</strong> #{value["weather"]}</p>
          <p><strong>Photos:</strong> #{value["photos"]}</p>
          <p><strong>Province:</strong> #{value["province"]}</p>
          <p><strong>Sitename:</strong> #{value["sitename"]}</p>
          <p><strong>No Stems:</strong> #{value["noStems"]}</p>
          <p><strong>No Flowers:</strong> #{value["noFlowers"]}</p>
          <p><strong>No Capsules:</strong> #{value["noCapsules"]}</p>
          <p><strong>Max Height:</strong> #{value["maxHeight"]}</p>
          <p><strong>No Ramets:</strong> #{value["noRamets"]}</p>
          <p><strong>Size of Infestation:</strong> #{value["sizeOfInf"]}</p>
          <p><strong>Percent Cover:</strong> #{value["percentCover"]}</p>
          <p><strong>Description:</strong> #{value["description"]}</p>
        </div>
      </div>
      """
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(:ok, html_content)
      # |> put_status(:ok)
      # |> json(%{message: "OK", value: value})
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
          "description" => "",
          "created_at" => System.os_time(:second)
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

  def search(conn, %{"search" => searchString}) do
    conn
    |> put_status(:ok)
    |> json([searchString, "moo"])
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
