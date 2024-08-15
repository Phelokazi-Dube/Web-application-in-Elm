defmodule FluffyWeb.PageController do
  alias Fluffy.CouchDBClient
  use FluffyWeb, :controller

  def home(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def upload(conn, params) do
    CouchDBClient.create(Map.delete(params, "_csrf_token"))
    # Expected: the _id of the new document.
    |> IO.inspect(label: "Document stored with ID")

    conn
    |> put_status(:ok)
    |> render(:home,
      layout: false,
      js_file: "uploading_data",
      extra_prepend: "The observation has been uploaded.  You can add another observation below."
    )
  end

  def uploading(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def sites(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def contact(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def publish(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def downloading(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def survey(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end
end
