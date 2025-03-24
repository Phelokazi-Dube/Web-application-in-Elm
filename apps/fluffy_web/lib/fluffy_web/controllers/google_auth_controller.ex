defmodule FluffyWeb.GoogleAuthController do
  use FluffyWeb, :controller

  @admin_emails ["phelokazidube@gmail.com", "y.motara@ru.ac.za"] # Add actual admin emails here

  def index(conn, %{"code" => code}) do
    case ElixirAuthGoogle.get_token(code, FluffyWeb.Endpoint.url()) do
      {:ok, token} ->
        case ElixirAuthGoogle.get_user_profile(token.access_token) do
          {:ok, profile} ->
            email = profile["email"]
            role = if email in @admin_emails, do: "admin", else: "user"

            conn
            |> put_session(:email, email)
            |> put_session(:role, role)  # Store user role in session
            |> IO.inspect()
            |> redirect(to: "/")

          {:error, reason} ->
            conn |> put_status(:unauthorized) |> json(%{error: reason})
        end

      {:error, reason} ->
        conn |> put_status(:unauthorized) |> json(%{error: reason})
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true) # Clears the session
    |> redirect(to: "/")
  end
end
