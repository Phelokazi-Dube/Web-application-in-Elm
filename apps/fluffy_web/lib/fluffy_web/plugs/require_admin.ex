defmodule FluffyWeb.Plugs.AdminOnly do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    # The :role key is added to the session in the GoogleAuthController
    case get_session(conn, :role) do
      "admin" ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized: Admins only"})
        |> halt()
    end
  end
end
