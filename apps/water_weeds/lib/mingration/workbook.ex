defmodule WaterWeeds.Migration.Workbook do
  @moduledoc """
  Reads CBC Excel workbooks for migration.
  """

  alias WaterWeeds.DataNormalizer

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
  def prepare_documents(file_path, sheet_name, collection) do
    with {:ok, %{index: sheet_index}} <- find_sheet(file_path, sheet_name),
         {:ok, table_id} <- Xlsxir.multi_extract(file_path, sheet_index) do
      try do
        links = if collection == "SurveyImages", do: survey_image_links(file_path), else: %{}

        table_id
        |> Xlsxir.get_list()
        |> rows_to_documents(collection, links)
      after
        Xlsxir.close(table_id)
      end
    end
  end

  @doc """
  Returns real external Drive hyperlinks attached to cells in the SurveyImages
  HLImage column, indexed by Excel row number. Old Windows paths are ignored.
  Reading the displayed cell text alone does not preserve Excel hyperlinks.
  """
  def survey_image_links(file_path) do
    with {:ok, [workbook_xml, workbook_rels]} <-
           read_zip_parts(file_path, ["xl/workbook.xml", "xl/_rels/workbook.xml.rels"]),
         sheet_tag when is_binary(sheet_tag) <-
           Enum.find(xml_tags(workbook_xml, "sheet"), fn tag ->
             xml_attributes(tag)["name"] == "SurveyImages"
           end),
         sheet_rid when is_binary(sheet_rid) <- xml_attributes(sheet_tag)["r:id"],
         target when is_binary(target) <- relationship_targets(workbook_rels)[sheet_rid] do
      # Only worksheet members inside xl/ are accepted; no filesystem paths.
      member = "xl/" <> String.trim_leading(target, "/")

      if String.starts_with?(member, "xl/worksheets/") and
           not String.contains?(member, "..") do
        rel_member =
          Path.join([Path.dirname(member), "_rels", Path.basename(member) <> ".rels"])

        with {:ok, [sheet_xml, sheet_rels]} <- read_zip_parts(file_path, [member, rel_member]) do
          links = relationship_targets(sheet_rels)
          Enum.reduce(xml_tags(sheet_xml, "hyperlink"), %{}, fn tag, acc ->
            attr = xml_attributes(tag)
            case {attr["ref"], links[attr["r:id"]]} do
              {"D" <> row, url} when is_binary(url) ->
                case {Integer.parse(row), drive_file_id(url)} do
                  {{number, ""}, {:ok, _id}} -> Map.put(acc, number, url)
                  _ -> acc
                end

              _ -> acc
            end
          end)
        else
          _ -> %{}
        end
      else
        %{}
      end
    else
      _ -> %{}
    end
  end

  @doc "Accept only Google Drive file URLs, never arbitrary Excel hyperlinks."
  def drive_file_id(url) when is_binary(url) do
    uri = URI.parse(url)
    path = uri.path || ""

    cond do
      uri.scheme != "https" or uri.host not in ["drive.google.com", "docs.google.com"] ->
        :error

      true ->
        case Regex.run(~r"^/file/d/([A-Za-z0-9_-]{10,})/(?:view|edit)?/?$", path) do
          [_, id] -> {:ok, id}
          _ -> :error
        end
    end
  end

  def drive_file_id(_), do: :error

  def drive_file_id(_), do: :error

  defp read_zip_parts(file_path, members) do
    options = [:memory, {:file_list, Enum.map(members, &String.to_charlist/1)}]

    case :zip.extract(String.to_charlist(file_path), options) do
      {:ok, parts} ->
        found = Map.new(parts, fn {name, data} -> {List.to_string(name), data} end)
        if Enum.all?(members, &Map.has_key?(found, &1)) do
          {:ok, Enum.map(members, &Map.fetch!(found, &1))}
        else
          {:error, :missing_zip_member}
        end

      error -> error
    end
  end

  defp xml_tags(xml, tag) do
    Regex.scan(Regex.compile!("<" <> tag <> "\\b[^>]*>"), xml)
    |> Enum.map(&hd/1)
  end

  defp xml_attributes(tag) do
    Regex.scan(~r/([A-Za-z_:][A-Za-z0-9_:.-]*)="([^"]*)"/, tag)
    |> Map.new(fn [_, key, val] -> {key, decode_xml(val)} end)
  end

  defp relationship_targets(xml) do
    xml_tags(xml, "Relationship")
    |> Map.new(fn tag ->
      attrs = xml_attributes(tag)
      {attrs["Id"], attrs["Target"]}
    end)
  end

  defp rows_to_documents([], _collection, _links), do: {:ok, []}

  defp rows_to_documents([headers | data_rows], collection, links) do
    valid_headers =
      headers
      |> Enum.with_index()
      |> Enum.reject(fn {header, _index} ->
        blank?(header)
      end)
      |> Enum.map(fn {header, index} ->
        {index, DataNormalizer.to_camel_case(to_string(header))}
      end)

    documents =
      data_rows
      |> Enum.with_index(2)
      |> Enum.reject(fn {row, _row_number} -> empty_row?(row) end)
      |> Enum.map(fn {row, row_number} ->
        document =
          Map.new(valid_headers, fn {index, header} ->
            {header, Enum.at(row, index)}
          end)

        document =
          case Map.get(links, row_number) do
            nil -> document
            link -> Map.put(document, "driveUrl", link)
          end

        {row_number, document}
      end)
      |> Enum.reject(fn {_row_number, document} ->
        average_reading?(collection, document)
      end)

    documents
    |> Enum.reduce_while({:ok, []}, fn {row_number, document}, {:ok, acc} ->
      case DataNormalizer.normalize_ids(document, collection) do
        {:ok, normalized} ->
          {:cont, {:ok, [normalized | acc]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_id, row_number, reason}}}
      end
    end)
    |> case do
      {:ok, normalized_documents} ->
        {:ok, Enum.reverse(normalized_documents)}

      error ->
        error
    end
  end

  # Previous worksheet includes one summary row per WHMID.
  # It is not an individual plant reading and has no numeric PlantNumber.
  defp average_reading?("WHMeasurementsReadings", %{"plantNumber" => plant_number})
       when is_binary(plant_number) do
    String.downcase(String.trim(plant_number)) == "average"
  end

  defp average_reading?(_collection, _document), do: false

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
