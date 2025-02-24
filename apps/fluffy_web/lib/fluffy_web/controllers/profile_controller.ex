defmodule AppFluffyWebWeb.ProfileController do
  use FluffyWeb, :controller

  def show(conn, _params) do
    case get_session(conn, :profile) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not logged in"})

      profile ->
        json(conn, %{
          given_name: profile["given_name"],
          picture: profile["picture"],
          email: profile["email"]
        })
    end
  end
end
