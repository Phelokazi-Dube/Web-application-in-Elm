defmodule FluffyWeb.PageController do
  use FluffyWeb, :controller

  def home(conn, params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def uploading(conn, params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def sites(conn, params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def contact(conn, params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def publish(conn, params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def downloading(conn, params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end
end
