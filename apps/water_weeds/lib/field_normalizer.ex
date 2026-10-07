defmodule WaterWeeds.FieldNormalizer do
  @moduledoc """
  Normalises external field names into FluffyWeb's camelCase convention.
  """

  @doc """
  Normalises all keys in a map using FluffyWeb's camelCase field convention.
  """
  def normalize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_camel_case(to_string(key)), value}
    end)
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
end
