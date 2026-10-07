defmodule FluffyWeb.ControllerHelpers do
    @moduledoc """
    Shared validation and data-transformation helpers used by FluffyWeb controllers.
    These functions normalise incoming CBC data before it is passed to the database.
    """

    alias WaterWeeds.FieldNormalizer

    @required_fields [
    {"surveyType", "Survey type"},
    {"weed", "Weed"},
    {"controlAgent", "Control agent"},
    {"location", "Location"},
    {"province", "Province"},
    {"date", "Date"}
  ]

  @doc """
  Returns the labels of required survey fields that are missing or blank.
  """
  def missing_required_fields(params) do
    @required_fields
    |> Enum.filter(fn {key, _label} ->
      value = Map.get(params, key)

      is_nil(value) or
        (is_binary(value) and String.trim(value) == "") or
        (key == "province" and value == "Select a province")
    end)
    |> Enum.map(fn {_key, label} -> label end)
  end

  @doc """
  Checks whether a survey date is a valid calendar date in MM/DD/YYYY format.
  """
  def valid_date?(date) when is_binary(date) do
    case Regex.run(~r/^(\d{2})\/(\d{2})\/(\d{4})$/, String.trim(date)) do
      [_, month_str, day_str, year_str] ->
        with {month, ""} <- Integer.parse(month_str),
             {day, ""} <- Integer.parse(day_str),
             {year, ""} <- Integer.parse(year_str),
             {:ok, _date} <- Date.new(year, month, day) do
          true
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  def valid_date?(_), do: false

  @doc """
  Converts a MongoDB document's `_id` into a JSON-friendly `id` string.
  """
  def normalize_mongo_id(doc) do
    doc
    # Add the "id" field with the string version of BSON _id
    |> Map.put("id", BSON.ObjectId.encode!(doc["_id"]))
    # Remove the original "_id" field
    |> Map.delete("_id")
  end

  @doc """
  Converts an external field name into the camelCase naming used by FluffyWeb.
  """
  defdelegate to_camel_case(key), to: FieldNormalizer

  @doc """
  Normalises all keys in a map to the camelCase naming used by FluffyWeb.
  """
  defdelegate normalize_keys(map), to: FieldNormalizer

  @doc """
  Adds a machine-readable date_dt value while preserving the original
  source date field.
  """
  def add_date_dt(document) do
    date_str = Map.get(document, "date")
    year_str = Map.get(document, "year")

    parsed =
      cond do
        not is_nil(parse_date_string(date_str)) -> parse_date_string(date_str)
        not is_nil(parse_date_string(year_str)) -> parse_date_string(year_str)
        true -> nil
      end
    Map.put(document, "date_dt", parsed)
  end

  @doc """
  Parses CBC full dates and year-only historical dates.
  Full dates are converted to `Date` values. Year-only values use January 1
  internally for `date_dt`, the original year field remains unchanged.
  """
  def parse_date_string(date_str) when is_binary(date_str) do
    date_str = String.trim(date_str)
    cond do
      # CBC full dates: M/D/YYYY, MM/D/YYYY, M/DD/YYYY or MM/DD/YYYY
      Regex.match?(~r/^\d{1,2}\/\d{1,2}\/\d{4}$/, date_str) ->
        case String.split(date_str, "/") do
          [month_str, day_str, year_str] ->
            with {month, ""} <- Integer.parse(month_str),
                {day, ""} <- Integer.parse(day_str),
                {year, ""} <- Integer.parse(year_str),
                {:ok, date} <- Date.new(year, month, day) do
              date
            else
              _ -> nil
            end

          _ ->
            nil
        end

      # Historical CBC records where only the year is known
      Regex.match?(~r/^\d{4}$/, date_str) ->
        case Date.new(String.to_integer(date_str), 1, 1) do
          {:ok, date} -> date
          _ -> nil
        end

      true ->
        nil
    end
  end

  # Fallback for unrecognized formats
  def parse_date_string(_), do: nil

  @doc """
  Converts latitude and longitude values into a GeoJSON Point.
  Coordinates may originate from CSV latitude/longitude fields or the
  location value submitted by the survey form.
  """
  def parse_location(document) do
    lat = Map.get(document, "latitude") || Map.get(document, "Latitude")
    lon = Map.get(document, "longitude") || Map.get(document, "Longitude")

    cond do
      # Case 1: CSV headers exist
      is_binary(lat) or is_binary(lon) ->
        if lat != "" and lon != "" do
          case {Float.parse(lat), Float.parse(lon)} do
            {{lat_f, ""}, {lon_f, ""}} ->
              document
              |> Map.put("location", %{
                "type" => "Point",
                "coordinates" => [lon_f, lat_f]
              })
              |> Map.drop(["latitude", "Latitude", "longitude", "Longitude"])

            _ ->
              Map.put(document, "location", nil)
          end
        else
          Map.put(document, "location", nil)
        end

      # Case 2: Form field "location" = "lat, lon"
      is_binary(Map.get(document, "location")) ->
        case String.split(document["location"], ",", trim: true) do
          [lat_s, lon_s] ->
            case {Float.parse(String.trim(lat_s)), Float.parse(String.trim(lon_s))} do
              {{lat_f, ""}, {lon_f, ""}} ->
                Map.put(document, "location", %{
                  "type" => "Point",
                  "coordinates" => [lon_f, lat_f]
                })

              _ ->
                Map.put(document, "location", nil)
            end

          _ ->
            Map.put(document, "location", nil)
        end

      # Default: neither CSV nor Form → still enforce consistency
      true ->
        Map.put(document, "location", nil)
    end
  end
end
