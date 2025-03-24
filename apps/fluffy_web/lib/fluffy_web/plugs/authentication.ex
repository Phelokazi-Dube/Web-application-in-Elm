defmodule FluffyWeb.Plugs.Authentication do
  import Plug.Conn
  import Phoenix.Controller

  @admin_emails ["y.motara@ru.ac.za", "phelokazidube@gmail.com"]  # List of admin emails

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :profile) do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/")
        |> halt()

      %{"email" => email} = profile ->
        role = fetch_user_role(email)  # Assign role dynamically
        updated_profile = Map.put(profile, "role", role)  # Add role to profile

        conn
        |> assign(:current_user, updated_profile)
        |> assign(:role, role)
        |> assign(:is_admin, role == "admin")  # Add a helper flag

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()
    end
  end

  defp fetch_user_role(email) do
    if email in @admin_emails, do: "admin", else: "user"
  end
end
