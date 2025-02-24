defmodule FluffyWeb.GoogleAuthController do
  use FluffyWeb, :controller

  def index(conn, %{"code" => code}) do
    case ElixirAuthGoogle.get_token(code, FluffyWeb.Endpoint.url()) do
      {:ok, token} ->
        case ElixirAuthGoogle.get_user_profile(token.access_token) do
          {:ok, profile} ->
            conn
            |> put_session(:profile, profile)
            |> redirect(to: "/profile")

          {:error, reason} ->
            conn |> put_status(:unauthorized) |> json(%{error: reason})
        end

      {:error, reason} ->
        conn |> put_status(:unauthorized) |> json(%{error: reason})
    end
  end
end
