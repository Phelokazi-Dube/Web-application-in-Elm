defmodule FluffyWeb.Plugs.CSVBuilder do
  @moduledoc """
  Builds CSV strings from normalized documents.
  """

  alias NimbleCSV.RFC4180, as: CSV

  @doc """
  Build a CSV string from a list of maps (documents).

  - `documents` is a list of maps (normalized).
  - `excluded_fields` is a list of keys to skip in CSV.
  """
  def build(documents, excluded_fields) do
    headers =
      documents
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.reject(&(&1 in excluded_fields))
      |> Enum.uniq()
      |> Enum.sort()

    rows =
      Enum.map(documents, fn doc ->
        Enum.map(headers, fn header ->
          Map.get(doc, header, "")
        end)
      end)

    ([headers] ++ rows)
    |> CSV.dump_to_iodata()
    |> IO.iodata_to_binary()
  end
end
