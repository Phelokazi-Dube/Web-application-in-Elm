defmodule FluffyWeb.GeocodingController do
  use FluffyWeb, :controller

  require Logger

  def reverse(conn, %{"lat" => lat, "lon" => lon}) do
    case System.get_env("GEOAPIFY_API_KEY") do
      nil ->
        Logger.error("GEOAPIFY_API_KEY is not configured")

        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Geocoding service is not configured"})

      api_key ->
        reverse_geocode(conn, lat, lon, api_key)
    end
  end

  defp reverse_geocode(conn, lat, lon, api_key) do
    url = "https://api.geoapify.com/v1/geocode/reverse"

    case Req.get(url,
          params: [
            lat: lat,
            lon: lon,
            apiKey: api_key,
            format: "json"
          ]
        ) do
      {:ok, %{status: 200, body: %{"results" => [result | _]}}} ->
        json(conn, %{
          province: result["state"],
          country: result["country"]
        })

      {:ok, %{status: status, body: body}} ->
        Logger.error(
          "Geoapify reverse geocoding failed with status #{status}: #{inspect(body)}"
        )

        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Unable to determine province and country"})

      {:error, reason} ->
        Logger.error("Geoapify request failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Reverse geocoding service unavailable"})
    end
  end
end
