defmodule FluffyWeb.Plugs.Authentication do
  import Plug.Conn
  use Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :profile) do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/")
        |> halt()

      profile ->
        Plug.Conn.assign(conn, :current_user, profile)
    end
  end
end
