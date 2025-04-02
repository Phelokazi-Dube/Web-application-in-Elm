defmodule FluffyWeb.GoogleAuthController do
  use FluffyWeb, :controller
  require Logger

  @admin_emails ["phelokazidube@gmail.com", "y.motara@ru.ac.za"] # Add actual admin emails here

  def index(conn, %{"code" => code}) do
    case ElixirAuthGoogle.get_token(code, FluffyWeb.Endpoint.url()) do
      {:ok, token} ->
        case ElixirAuthGoogle.get_user_profile(token.access_token) do
          {:ok, profile} ->
            # Logger.debug("Profile: #{inspect(profile)}")
            email = profile[:email]
            # Logger.debug("Obtained email: #{email}")
            role = if email in @admin_emails, do: "admin", else: "user"

            # Retrieve the stored redirect path or default to "/"
            redirect_path = get_session(conn, :redirect_after_login) || "/"

            conn
            |> configure_session(renew: true)  # Renew the session for security
            |> put_session(:profile, profile)
            |> put_session(:role, role)  # Store user role in session
            |> IO.inspect()
            |> delete_session(:redirect_after_login)  # Remove the session key after use
            |> redirect(to: redirect_path)

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
