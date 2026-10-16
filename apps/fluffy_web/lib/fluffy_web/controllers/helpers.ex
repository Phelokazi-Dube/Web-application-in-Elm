
defmodule FluffyWeb.ControllerHelpers do
  @moduledoc """
  Shared validation and data-transformation helpers used by FluffyWeb controllers.
  These functions normalise incoming CBC data before it is passed to the database.
  """

  alias WaterWeeds.DataNormalizer

  @required_fields [
    {"surveyType", "Survey type"},
    {"weed", "Weed"},
    {"controlAgent", "Control agent"},
    {"geospatialCoordinates", "Geospatial coordinates"},
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
  defdelegate to_camel_case(key), to: DataNormalizer

  @doc """
  Normalises all keys in a map to the camelCase naming used by FluffyWeb.
  """
  defdelegate normalize_keys(map), to: DataNormalizer

  @doc """
  Validates and normalises coordinates into a GeoJSON Point.
  """
  defdelegate normalize_location(document), to: DataNormalizer

  @doc """
  Compatibility wrapper for existing location-normalisation callers.
  """
  defdelegate parse_location(document), to: DataNormalizer

  @doc """
  Adds date_dt when a valid date or year is available.

  Preserves existing date_dt when neither source field is supplied.
  For validation-sensitive operations, use normalize_date/1 instead.
  """
  def add_date_dt(document) do
    case normalize_date(document) do
      {:ok, normalized} ->
        normalized

      {:ok, normalized, :clear_date_dt} ->
        normalized

      {:error, _reason} ->
        document
    end
  end

  @doc """
  Validates and normalises supplied date/year fields.

  Returns:
  - {:ok, document} when no date/year is supplied, or a valid date is found.
  - {:ok, document, :clear_date_dt} when date/year was explicitly cleared
    and no usable source date remains.
  - {:error, reason} for invalid values.

  The controller must handle :clear_date_dt using MongoDB $unset.
  """
  def normalize_date(document) when is_map(document) do
    date_present? = Map.has_key?(document, "date")
    year_present? = Map.has_key?(document, "year")

    cond do
      not date_present? and not year_present? ->
        {:ok, document}

      true ->
        date = Map.get(document, "date")
        year = Map.get(document, "year")

        cond do
          date_present? and not blank_date?(date) ->
            case parse_date_string(date) do
              %Date{} = parsed ->
                {:ok, Map.put(document, "date_dt", parsed)}

              nil ->
                {:error, :invalid_date}
            end

          year_present? and not blank_date?(year) ->
            case parse_date_string(year) do
              %Date{} = parsed ->
                {:ok, Map.put(document, "date_dt", parsed)}

              nil ->
                {:error, :invalid_year}
            end

          true ->
            {:ok, Map.delete(document, "date_dt"), :clear_date_dt}
        end
    end
  end


  defp blank_date?(nil), do: true
  defp blank_date?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank_date?(_), do: false

  @doc """
  Parses CBC dates without changing their original stored representation.

  Supported:
  - M/D/YYYY and MM/DD/YYYY
  - YYYY-MM-DD
  - YYYY (stored internally as January 1)
  - Date values and integer years
  """
  def parse_date_string(%Date{} = date), do: date

  def parse_date_string(year) when is_integer(year) do
    if year >= 1 and year <= 9999 do
      case Date.new(year, 1, 1) do
        {:ok, date} -> date
        _ -> nil
      end
    else
      nil
    end
  end

  def parse_date_string(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      # CBC full dates: M/D/YYYY, MM/D/YYYY, M/DD/YYYY or MM/DD/YYYY
      Regex.match?(~r/^\d{1,2}\/\d{1,2}\/\d{4}$/, value) ->
        case String.split(value, "/") do
          [month_string, day_string, year_string] ->
            with {month, ""} <- Integer.parse(month_string),
                 {day, ""} <- Integer.parse(day_string),
                 {year, ""} <- Integer.parse(year_string),
                 {:ok, date} <- Date.new(year, month, day) do
              date
            else
              _ -> nil
            end

          _ ->
            nil
        end

      # Historical CBC records where only the year is known
      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, value) ->
        case Date.from_iso8601(value) do
          {:ok, date} -> date
          _ -> nil
        end

      Regex.match?(~r/^\d{4}$/, value) ->
        parse_date_string(String.to_integer(value))

      true ->
        nil
    end
  end

  def parse_date_string(_), do: nil
end
