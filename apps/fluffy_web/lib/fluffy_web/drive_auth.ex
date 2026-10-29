defmodule FluffyWeb.DriveAuth do
  @moduledoc """
  Temporary, server-side Google Drive OAuth credentials for a signed-in admin.
  Tokens never enter a browser session or the workbook. Reconnect after restart.
  """
  use GenServer

  @token_endpoint "https://oauth2.googleapis.com/token"
  @profile_endpoint "https://www.googleapis.com/oauth2/v2/userinfo"
  @drive_scope "https://www.googleapis.com/auth/drive.readonly"

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  @impl true
  def init(state), do: {:ok, state}

  def authorization_url(state, email) do
    query = URI.encode_query(%{
      "client_id" => System.fetch_env!("GOOGLE_CLIENT_ID"),
      "redirect_uri" => redirect_uri(),
      "response_type" => "code",
      "scope" => "openid email " <> @drive_scope,
      "state" => state,
      "access_type" => "offline",
      "prompt" => "consent",
      "login_hint" => email
    })

    "https://accounts.google.com/o/oauth2/v2/auth?" <> query
  end

  def redirect_uri, do: System.fetch_env!("GOOGLE_DRIVE_REDIRECT_URI")

  def exchange_code(code, logged_in_email) do
    with {:ok, %{status: 200, body: tokens}} <-
           Req.post(@token_endpoint,
             form: %{
               "code" => code,
               "client_id" => System.fetch_env!("GOOGLE_CLIENT_ID"),
               "client_secret" => System.fetch_env!("GOOGLE_CLIENT_SECRET"),
               "redirect_uri" => redirect_uri(),
               "grant_type" => "authorization_code"
             }, retry: false),
         true <- @drive_scope in String.split(tokens["scope"] || ""),
         {:ok, %{status: 200, body: %{"email" => email}}} <-
           Req.get(@profile_endpoint,
             auth: {:bearer, tokens["access_token"]}, retry: false),
         true <- is_binary(email) and
                   String.downcase(email) == String.downcase(logged_in_email) do
      id = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      GenServer.call(__MODULE__, {:store, id, email, tokens})
      {:ok, id}
    else
      _ -> {:error, :google_authorization_failed}
    end
  end

  def connected?(id, email) when is_binary(id) and is_binary(email) do
    GenServer.call(__MODULE__, {:connected?, id, String.downcase(email)})
  end
  def connected?(_, _), do: false

  def access_token(id, email) when is_binary(id) and is_binary(email) do
    GenServer.call(__MODULE__, {:access_token, id, String.downcase(email)}, 45_000)
  end
  def access_token(_, _), do: {:error, :not_authorized}

  @impl true
  def handle_call({:store, id, email, tokens}, _from, state) do
    entry = token_entry(email, tokens)
    {:reply, :ok, Map.put(state, id, entry)}
  end

  def handle_call({:connected?, id, email}, _from, state) do
    {:reply, match?(%{email: ^email}, Map.get(state, id)), state}
  end

  def handle_call({:access_token, id, email}, _from, state) do
    case Map.get(state, id) do
      %{email: ^email, expires_at: expires_at, access_token: token} = entry ->
        if System.system_time(:second) < expires_at do
          {:reply, {:ok, token}, state}
        else
          case refresh(entry) do
            {:ok, new_entry} ->
              {:reply, {:ok, new_entry.access_token}, Map.put(state, id, new_entry)}
            error -> {:reply, error, state}
          end
        end
      _ -> {:reply, {:error, :not_authorized}, state}
    end
  end

  defp token_entry(email, tokens, old_refresh_token \\ nil) do
    %{
      email: String.downcase(email),
      access_token: tokens["access_token"],
      refresh_token: tokens["refresh_token"] || old_refresh_token,
      expires_at: System.system_time(:second) + (tokens["expires_in"] || 3600) - 90
    }
  end

  defp refresh(%{refresh_token: nil}), do: {:error, :reconnect_google_drive}
  defp refresh(entry) do
    case Req.post(@token_endpoint,
           form: %{
             "client_id" => System.fetch_env!("GOOGLE_CLIENT_ID"),
             "client_secret" => System.fetch_env!("GOOGLE_CLIENT_SECRET"),
             "refresh_token" => entry.refresh_token,
             "grant_type" => "refresh_token"
           }, retry: false) do
      {:ok, %{status: 200, body: tokens}} ->
        {:ok, token_entry(entry.email, tokens, entry.refresh_token)}
      _ -> {:error, :reconnect_google_drive}
    end
  end
end
