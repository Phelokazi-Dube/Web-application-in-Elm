defmodule FluffyWeb.HistoricalPhotoImporter do
  @moduledoc """
  Downloads *only* explicitly hyperlinked historical CBC photographs into GridFS.
  The workbook's old Windows paths are retained as source metadata and never
  resolved by filename guessing. Existing GridFS associations are reused.
  """
  require Logger
  alias WaterWeeds.Migration.Workbook
  alias WaterWeeds.MongoDBClient
  alias FluffyWeb.DriveAuth

  @image_types ["image/jpeg", "image/png", "image/gif", "image/webp"]
  @collection "SurveyImages"

  def run(workbook_path, credential_id, admin_email) do
    with {:ok, source_records} <- Workbook.prepare_documents(workbook_path, "SurveyImages", @collection) do
      available = Enum.filter(source_records, &valid_link?/1)
      counts = %{linked_records: length(available), imported: 0, reused: 0, failed: 0, unresolved: length(source_records) - length(available), errors: []}

      result =
        Enum.reduce(available, {counts, %{}}, fn record, {counts, cache} ->
          case migrate_one(record, credential_id, admin_email, cache) do
            {:ok, outcome, cache} ->
              {Map.update!(counts, outcome, &(&1 + 1)), cache}
            {:error, code, cache} ->
              label = record["surveyImageId"]
              Logger.warning("Historical survey image #{inspect(label)} could not be migrated: #{inspect(code)}")
              updated = counts
                |> Map.update!(:failed, &(&1 + 1))
                |> Map.update!(:errors, &[ %{surveyImageId: label, reason: code} | &1])
              {updated, cache}
          end
        end)
        |> elem(0)

      {:ok, Map.update!(result, :errors, &Enum.reverse/1)}
    end
  end

  defp valid_link?(record) do
    match?({:ok, _}, Workbook.drive_file_id(record["driveUrl"]))
  end

  defp migrate_one(source, credential_id, email, cache) do
    {:ok, file_id} = Workbook.drive_file_id(source["driveUrl"])
    key = %{"surveyImageId" => source["surveyImageId"]}

    case MongoDBClient.get_all_documents(@collection, key) do
      [record] ->
        cond do
          present_id?(record["gridfsId"]) ->
            {:ok, :reused, Map.put(cache, file_id, record["gridfsId"])}

          true ->
            with {:ok, gridfs_id, outcome} <- image_id(file_id, cache, credential_id, email),
                 {:ok, _} <- MongoDBClient.update_document_fields(
                   @collection, record["_id"],
                   %{"gridfsId" => gridfs_id, "driveFileId" => file_id}) do
              {:ok, outcome, Map.put(cache, file_id, gridfs_id)}
            else
              {:error, reason} -> {:error, reason, cache}
              _ -> {:error, :update_failed, cache}
            end
        end
      _ -> {:error, :missing_or_duplicate_image_record, cache}
    end
  end

  defp image_id(id, cache, credential_id, email) do
    case Map.get(cache, id) do
      existing when is_binary(existing) -> {:ok, existing, :reused}
      _ ->
        # Previous migrations may have stored the file for another survey.
        case Enum.find(MongoDBClient.get_all_documents(@collection, %{"driveFileId" => id}),
               &(present_id?(&1["gridfsId"]))) do
          %{"gridfsId" => existing} -> {:ok, existing, :reused}
          _ -> fetch_and_upload(id, credential_id, email)
        end
    end
  end

  defp fetch_and_upload(file_id, credential_id, email) do
    with {:ok, token} <- DriveAuth.access_token(credential_id, email),
         {:ok, %{status: 200, body: info}} <-
           Req.get("https://www.googleapis.com/drive/v3/files/" <> file_id,
             auth: {:bearer, token},
             params: [fields: "id,name,mimeType,capabilities(canDownload)", supportsAllDrives: "true"],
             retry: false),
         true <- get_in(info, ["capabilities", "canDownload"]) == true,
         true <- info["mimeType"] in @image_types do
      temporary_download(file_id, info, token)
    else
      {:ok, %{status: 401}} -> {:error, :authorization_expired}
      {:ok, %{status: 403}} -> {:error, :access_denied}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:google_http_error, status}}
      false -> {:error, :not_downloadable_or_unsupported_image}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :download_failed}
    end
  end

  defp temporary_download(file_id, info, token) do
    directory = Path.join(System.tmp_dir!(), "fluffy_cbc_photos")
    :ok = File.mkdir_p(directory)
    :ok = File.chmod(directory, 0o700)
    path = Path.join(directory, Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false))

    try do
      case Req.get("https://www.googleapis.com/drive/v3/files/" <> file_id,
             auth: {:bearer, token},
             params: [alt: "media", supportsAllDrives: "true"],
             into: File.stream!(path),
             receive_timeout: 120_000,
             retry: false) do
        {:ok, %{status: 200}} ->
          case MongoDBClient.upload_image_from_path(
                 Path.basename(info["name"] || file_id), path,
                 %{content_type: info["mimeType"], origin: "cbc_historical_drive", driveFileId: file_id}) do
            {:ok, mongo_id} -> {:ok, BSON.ObjectId.encode!(mongo_id), :imported}
            {:error, reason} -> {:error, reason}
          end
        {:ok, %{status: 401}} -> {:error, :authorization_expired}
        {:ok, %{status: 403}} -> {:error, :access_denied}
        {:ok, %{status: 404}} -> {:error, :not_found}
        {:ok, %{status: status}} -> {:error, {:google_http_error, status}}
        {:error, reason} -> {:error, {:network_error, inspect(reason)}}
      end
    rescue
      exception ->
        Logger.error("Historical photo download error: #{Exception.message(exception)}")
        {:error, :download_failed}
    after
      File.rm(path)
    end
  end

  defp present_id?(value) when is_binary(value), do: match?({:ok, _}, BSON.ObjectId.decode(value))
  defp present_id?(%BSON.ObjectId{}), do: true
  defp present_id?(_), do: false
end
