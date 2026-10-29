defmodule FluffyWeb.DriveAuthController do
  use FluffyWeb, :controller
  alias FluffyWeb.DriveAuth

  def connect(conn, _params) do
    email = email(conn)
    state = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    conn
    |> put_session(:drive_oauth_state, state)
    |> redirect(external: DriveAuth.authorization_url(state, email))
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    expected = get_session(conn, :drive_oauth_state)
    conn = delete_session(conn, :drive_oauth_state)

    if is_binary(expected) and byte_size(expected) > 0 and
         Plug.Crypto.secure_compare(state, expected) do
      case DriveAuth.exchange_code(code, email(conn)) do
        {:ok, id} ->
          conn
          |> put_session(:drive_migration_token_id, id)
          |> put_flash(:info, "Google Drive connected for CBC photograph migration.")
          |> redirect(to: ~p"/admin/migration/review")
        {:error, _} -> failed(conn)
      end
    else
      failed(conn)
    end
  end

  def callback(conn, _params), do: failed(conn)

  defp failed(conn) do
    conn
    |> put_flash(:error, "Google Drive authorization failed. Please reconnect using the same Google account as your FluffyWeb admin login.")
    |> redirect(to: ~p"/admin/migration/review")
  end

  defp email(conn) do
    profile = get_session(conn, :profile) || %{}
    profile[:email] || profile["email"] || ""
  end
end
