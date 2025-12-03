defmodule FluffyWeb.Plugs.Normalizer do
  @moduledoc """
  Normalizes MongoDB documents for CSV export or other purposes.
  """

  # Public function to normalize one document
  def normalize(doc) when is_map(doc) do
    doc
    |> Map.drop(["_id", "photos", "approved_at", "approved_by"])
    |> Map.put("id", BSON.ObjectId.encode!(doc["_id"]))
    |> Enum.into(%{}, fn {k, v} ->
      {to_string(k), encode_value(v)}
    end)
  end

  defp encode_value(value) when is_binary(value), do: value
  defp encode_value(value) when is_number(value), do: to_string(value)
  defp encode_value(value) when is_boolean(value), do: to_string(value)
  defp encode_value(nil), do: ""
  defp encode_value(value) when is_list(value), do: Jason.encode!(value)
  defp encode_value(value) when is_map(value), do: Jason.encode!(value)
end
