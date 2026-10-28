defmodule WaterWeeds.DataNormalizer do
  @moduledoc """
  Shared field-name, coordinate and GeoJSON normalization
  for incoming CBC data.
  """

  @integer_id_fields ~w(
    surveyId surveyImageId swaid
    siteInspectionId siteInspectionWeedId
    weedId controlAgentId
    whmid plantNumber barId implementerId
    dataSourceId dataStatusId dataAccessId
  )

  @string_id_fields ~w(
    siteId locationId municipalId
    districtId regionId countryId continentId
    planetId
  )

  @collection_integer_id_fields %{
    "SurveyControlAgents" => ["id"]
  }

  @doc """
  Normalises all keys in a map using FluffyWeb's camelCase field convention.
  """
  def normalize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_camel_case(to_string(key)), value}
    end)
  end

  @doc """
  Compatibility wrapper for existing callers.

  Invalid location input is preserved rather than replaced with nil.
  Controllers should use normalize_location/1 and handle errors explicitly.
  """
  def parse_location(document) do
    case normalize_location(document) do
      {:ok, normalized} -> normalized
      {:error, _reason} -> document
    end
  end

  @doc """
  Converts almost any header string (e.g. COUNTRY_ID, DataACCESSID) into clean camelCase.
  Relevant for CSV header to the camelCase field naming used by FluffyWeb.
  """
  def to_camel_case(key) when is_binary(key) do
    key
    |> String.trim()
    |> String.replace("%", " Percent ")
    # DGCFinal -> DGC Final, ControlAgent -> Control Agent
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1 \\2")
    |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1 \\2")
    # spaces, underscores, brackets, punctuation etc. become separators
    |> String.replace(~r/[^a-zA-Z0-9]+/, " ")
    |> String.split(" ", trim: true)
    |> camelize_words()
  end

  defp camelize_words([]), do: ""

  defp camelize_words([first | rest]) do
    String.downcase(first) <>
      Enum.map_join(rest, fn word ->
        word
        |> String.downcase()
        |> String.capitalize()
      end)
  end

  @doc """
  Normalises a record's own coordinates into a GeoJSON Point.

  Accepts:
  - Separate latitude and longitude fields
  - A "latitude, longitude" string from the survey form
  - A GeoJSON Point under geospatialCoordinates

  Preserves original latitude and longitude fields.
  Does not interpret the legacy location field as coordinates.
  """
  def normalize_location(document) when is_map(document) do
    latitude_present? =
      Map.has_key?(document, "latitude") or
        Map.has_key?(document, "Latitude")

    longitude_present? =
      Map.has_key?(document, "longitude") or
        Map.has_key?(document, "Longitude")

    cond do
      Map.has_key?(document, "geospatialCoordinates") ->
        normalize_geospatial_value(document)

      latitude_present? or longitude_present? ->
        latitude = Map.get(document, "latitude", Map.get(document, "Latitude"))
        longitude = Map.get(document, "longitude", Map.get(document, "Longitude"))

        with {:ok, lat} <- parse_coordinate(latitude),
            {:ok, lon} <- parse_coordinate(longitude),
            :ok <- validate_coordinate_range(lat, lon) do
          {:ok,
          Map.put(
            document,
            "geospatialCoordinates",
            geojson_point(lat, lon)
          )}
        end

      true ->
        {:ok, document}
    end
  end

  def prepare_coordinates(document, existing) do
    coordinate_fields = ["latitude", "longitude"]

    has_coordinates? =
      Enum.any?(coordinate_fields, &Map.has_key?(document, &1))

    if has_coordinates? do
      raw_coordinates = Map.take(document, coordinate_fields)

      case normalize_location(raw_coordinates) do
        {:ok, %{"geospatialCoordinates" => point}} ->
          Map.put(document, "geospatialCoordinates", point)

        _ ->
          document = Map.delete(document, "geospatialCoordinates")

          if is_map(existing) and
            match?(
              {:ok, %{"geospatialCoordinates" => _}},
              normalize_location(
                Map.take(existing, ["geospatialCoordinates"])
              )
            ) do
            Map.drop(document, coordinate_fields)
          else
            document
          end
      end
    else
      Map.delete(document, "geospatialCoordinates")
    end
  end

  @doc """
  Normalises a CBC identifier according to its declared type.

  Numeric IDs become integers.
  Text IDs remain strings, preserving leading zeros.
  """
  def normalize_id(value, :integer) when is_integer(value), do: {:ok, value}

  def normalize_id(value, :integer) when is_float(value) do
    if value == trunc(value) do
      {:ok, trunc(value)}
    else
      {:error, :invalid_integer_id}
    end
  end

  def normalize_id(value, :integer) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_integer_id}
    end
  end

  def normalize_id(value, :string) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :empty_id}
      id -> {:ok, id}
    end
  end

  def normalize_id(value, :string) when is_integer(value) do
    {:ok, Integer.to_string(value)}
  end

  def normalize_id(nil, _type), do: {:error, :missing_id}
  def normalize_id(_value, _type), do: {:error, :invalid_id}

  @doc """
  Normalises known CBC ID fields while preserving all other fields.

  Uses collection-specific rules where needed.
  Blank optional IDs are retained as-is. Invalid non-blank IDs
  return a field-specific error.

  MongoDB's _id is never normalised.
  """
  def normalize_ids(document, collection) when is_map(document) do
    integer_fields =
      @integer_id_fields ++
        Map.get(@collection_integer_id_fields, collection, [])

    Enum.reduce_while(document, {:ok, %{}}, fn {field, value}, {:ok, result} ->
      type =
        cond do
          field == "_id" -> nil
          field in integer_fields -> :integer
          field in @string_id_fields -> :string
          true -> nil
        end

      cond do
        is_nil(type) ->
          {:cont, {:ok, Map.put(result, field, value)}}

        blank_id?(value) ->
          {:cont, {:ok, Map.put(result, field, value)}}

        true ->
          case normalize_id(value, type) do
            {:ok, normalized} ->
              {:cont, {:ok, Map.put(result, field, normalized)}}

            {:error, reason} ->
              {:halt, {:error, {field, reason}}}
          end
      end
    end)
  end

  defp blank_id?(nil), do: true
  defp blank_id?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_id?(_), do: false

  defp normalize_geospatial_value(document) do
    case document["geospatialCoordinates"] do
      %{"type" => "Point", "coordinates" => [lon, lat]} ->
        with {:ok, lat} <- parse_coordinate(lat),
            {:ok, lon} <- parse_coordinate(lon),
            :ok <- validate_coordinate_range(lat, lon) do
          {:ok,
          Map.put(
            document,
            "geospatialCoordinates",
            geojson_point(lat, lon)
          )}
        end

      value when is_binary(value) ->
        value = String.trim(value)

        cond do
          value == "" ->
            {:error, :empty_coordinates}

          String.starts_with?(value, "{") ->
            case Jason.decode(value) do
              {:ok, decoded} when is_map(decoded) ->
                normalize_geospatial_value(
                  Map.put(document, "geospatialCoordinates", decoded)
                )

              _ ->
                {:error, :invalid_coordinates_json}
            end

          true ->
            case String.split(value, ",") do
              [latitude, longitude] ->
                with {:ok, lat} <- parse_coordinate(latitude),
                    {:ok, lon} <- parse_coordinate(longitude),
                    :ok <- validate_coordinate_range(lat, lon) do
                  {:ok,
                  Map.put(
                    document,
                    "geospatialCoordinates",
                    geojson_point(lat, lon)
                  )}
                end

              _ ->
                {:error, :invalid_coordinates_format}
            end
        end

      _ ->
        {:error, :invalid_coordinates_format}
    end
  end

  defp parse_coordinate(value) when is_integer(value) do
    {:ok, value * 1.0}
  end

  defp parse_coordinate(value) when is_float(value) do
    if finite_coordinate?(value), do: {:ok, value}, else: {:error, :invalid_coordinate}
  end

  defp parse_coordinate(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} ->
        if finite_coordinate?(number),
          do: {:ok, number},
          else: {:error, :invalid_coordinate}

      _ ->
        {:error, :invalid_coordinate}
    end
  end

  defp parse_coordinate(_), do: {:error, :invalid_coordinate}

  defp finite_coordinate?(value) do
    value == value and abs(value) <= 180.0
  end

  defp validate_coordinate_range(lat, lon)
       when lat >= -90.0 and lat <= 90.0 and
              lon >= -180.0 and lon <= 180.0,
       do: :ok

  defp validate_coordinate_range(_, _), do: {:error, :coordinate_out_of_range}

  defp geojson_point(lat, lon) do
    %{
      "type" => "Point",
      "coordinates" => [lon, lat]
    }
  end
end
