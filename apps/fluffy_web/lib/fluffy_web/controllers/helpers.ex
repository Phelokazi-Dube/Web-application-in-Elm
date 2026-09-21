defmodule FluffyWeb.ContollerHelpers do
  @required_fields [
    {"surveyType", "Survey type"},
    {"weed", "Weed"},
    {"controlAgent", "Control agent"},
    {"location", "Location"},
    {"province", "Province"},
    {"date", "Date"}
  ]

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
end
