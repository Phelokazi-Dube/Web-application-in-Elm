defmodule WaterWeeds.Migration.Workbook do
  @moduledoc """
  Reads CBC Excel workbooks for migration.
  """

  alias WaterWeeds.FieldNormalizer

  @doc """
  Returns the worksheets in workbook order.

  Each worksheet contains its Excel name and zero-based Xlsxir index.
  """
  def sheets(file_path) do
    case Xlsxir.XlsxFile.initialize(file_path) do
      %Xlsxir.XlsxFile{} = xlsx ->
        try do
          xml = xlsx.workbook_xml_file.content

          sheets =
            Regex.scan(
              ~r/<sheet\b[^>]*\bname="([^"]+)"[^>]*\bsheetId="([^"]+)"[^>]*\/?>/,
              xml
            )
            |> Enum.with_index()
            |> Enum.map(fn {[_, name, sheet_id], index} ->
              %{
                name: decode_xml(name),
                sheet_id: String.to_integer(sheet_id),
                index: index
              }
            end)

          {:ok, sheets}
        after
          close_xlsx(xlsx)
        end

      {:error, reason} ->
        {:error, {:invalid_workbook, reason}}

      other ->
        {:error, {:invalid_workbook, other}}
    end
  end

  @doc """
  Finds a worksheet by its Excel tab name.
  """
  def find_sheet(file_path, sheet_name) do
    with {:ok, sheets} <- sheets(file_path) do
      case Enum.find(sheets, &(&1.name == sheet_name)) do
        nil ->
          {:error, {:sheet_not_found, sheet_name}}

        sheet ->
          {:ok, sheet}
      end
    end
  end

  @doc """
  Reads a worksheet by its Excel tab name and converts its rows into
  normalised document maps.
  """
  def prepare_documents(file_path, sheet_name) do
    with {:ok, %{index: sheet_index}} <- find_sheet(file_path, sheet_name),
         {:ok, table_id} <- Xlsxir.multi_extract(file_path, sheet_index) do
      try do
        table_id
        |> Xlsxir.get_list()
        |> rows_to_documents()
      after
        Xlsxir.close(table_id)
      end
    end
  end

  defp rows_to_documents([]), do: {:ok, []}

  defp rows_to_documents([headers | data_rows]) do
    valid_headers =
      headers
      |> Enum.with_index()
      |> Enum.reject(fn {header, _index} ->
        blank?(header)
      end)
      |> Enum.map(fn {header, index} ->
        {index, FieldNormalizer.to_camel_case(to_string(header))}
      end)

    documents =
      data_rows
      |> Enum.reject(&empty_row?/1)
      |> Enum.map(fn row ->
        Map.new(valid_headers, fn {index, header} ->
          {header, Enum.at(row, index)}
        end)
      end)

    {:ok, documents}
  end

  defp empty_row?(row) do
    Enum.all?(row, &blank?/1)
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp decode_xml(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  defp close_xlsx(xlsx) do
    [xlsx.shared_strings, xlsx.styles, xlsx.workbook]
    |> Enum.reject(&is_nil/1)
    |> Enum.each(fn table ->
      if :ets.info(table) != :undefined do
        :ets.delete(table)
      end
    end)

    :ok
  end
end
