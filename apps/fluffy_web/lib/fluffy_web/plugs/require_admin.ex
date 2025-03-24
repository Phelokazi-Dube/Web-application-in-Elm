defmodule FluffyWeb.Plugs.AdminOnly do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:role] do
      "admin" ->
        IO.inspect(conn)

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized: Admins only"})
        |> halt()
    end
  end
end
