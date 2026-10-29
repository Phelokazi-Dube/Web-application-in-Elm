defmodule FluffyWeb.MigrationController do
  use FluffyWeb, :controller

  alias WaterWeeds.Migration.Importer
  alias FluffyWeb.{DriveAuth, HistoricalPhotoImporter, MigrationJobs}
  require Logger

  def index(conn, _params) do
    render(conn, :index, auth_assigns(conn))
  end

  def review(conn, _params) do
    case get_session(conn, :migration_workbook_path) do
      path when is_binary(path) ->
        if File.regular?(path) do
          case Importer.validate(path) do
            {:ok, validation} ->
              render(conn, :validation, auth_assigns(conn) ++ [
                filename: get_session(conn, :migration_workbook_name) || "CBC workbook",
                validation: validation
              ])
            {:error, _} -> redirect(conn, to: ~p"/admin/migration")
          end
        else
          redirect(conn, to: ~p"/admin/migration")
        end
      _ -> redirect(conn, to: ~p"/admin/migration")
    end
  end

  def job(conn, %{"id" => id}) do
    case MigrationJobs.get(id, admin_email(conn)) do
      {:ok, %{status: :running} = job} ->
        render(conn, :processing, auth_assigns(conn) ++ [job: job, job_id: id])

      {:ok, %{status: :completed, result: result} = job} ->
        render(conn, :success, auth_assigns(conn) ++ [
          result: result,
          filename: job.filename
        ])

      {:ok, %{status: :failed} = job} ->
        conn
        |> put_flash(:error, "Migration did not finish: #{inspect(job.reason)}. Already imported records remain unchanged. Revalidate and retry to resume.")
        |> redirect(to: ~p"/admin/migration")

      _ -> send_resp(conn, 404, "Migration job not found")
    end
  end

  def validate(conn, %{"workbook" => %Plug.Upload{} = upload}) do
    case String.downcase(Path.extname(upload.filename)) do
      ".xlsx" ->
        validate_workbook(conn, upload)

      _ ->
        conn
        |> put_flash(:error, "Please upload an Excel .xlsx workbook.")
        |> redirect(to: ~p"/admin/migration")
    end
  end

  def validate(conn, _params) do
    conn
    |> put_flash(:error, "Please select a workbook to upload.")
    |> redirect(to: ~p"/admin/migration")
  end

  def import(conn, _params) do
    case get_session(conn, :migration_workbook_path) do
      nil ->
        conn
        |> put_flash(
          :error,
          "No validated workbook is available. Please upload and validate a workbook first."
        )
        |> redirect(to: ~p"/admin/migration")

      workbook_path ->
        import_workbook(conn, workbook_path)
    end
  end

  defp import_workbook(conn, workbook_path) do
    email = admin_email(conn)
    credential_id = get_session(conn, :drive_migration_token_id)

    cond do
      not File.regular?(workbook_path) ->
        conn
        |> delete_session(:migration_workbook_path)
        |> delete_session(:migration_workbook_name)
        |> put_flash(:error, "The validated workbook is no longer available. Please upload it again.")
        |> redirect(to: ~p"/admin/migration")

      not DriveAuth.connected?(credential_id, email) ->
        conn
        |> put_flash(:error, "Connect your Google Drive account before starting CBC migration.")
        |> redirect(to: ~p"/admin/migration/review")

      true ->
        filename = get_session(conn, :migration_workbook_name) || "CBC workbook"
        job_id = MigrationJobs.create(email, filename)

        case Task.Supervisor.start_child(FluffyWeb.MigrationTaskSupervisor, fn ->
               try do
                 result =
                   with {:ok, base} <- Importer.import(workbook_path),
                        {:ok, photo_counts} <- HistoricalPhotoImporter.run(workbook_path, credential_id, email) do
                     {:ok, Map.put(base, :photos, photo_counts)}
                   end

                 case result do
                   {:ok, data} -> MigrationJobs.finish(job_id, %{status: :completed, result: data})
                   {:error, reason} -> MigrationJobs.finish(job_id, %{status: :failed, reason: reason})
                 end
               rescue
                 exception ->
                   Logger.error("CBC migration job failed: #{Exception.message(exception)}")
                   MigrationJobs.finish(job_id, %{status: :failed, reason: :unexpected_error})
               after
                 File.rm(workbook_path)
               end
             end) do
          {:ok, _pid} ->
            conn
            |> delete_session(:migration_workbook_path)
            |> delete_session(:migration_workbook_name)
            |> redirect(to: ~p"/admin/migration/jobs/#{job_id}")
          {:error, _reason} ->
            File.rm(workbook_path)
            conn
            |> put_flash(:error, "Unable to start migration task.")
            |> redirect(to: ~p"/admin/migration")
        end
    end
  end

  defp validate_workbook(conn, upload) do
    with {:ok, stored_path} <- store_workbook(upload),
         {:ok, validation} <- Importer.validate(stored_path) do
      conn
      |> put_session(:migration_workbook_path, stored_path)
      |> put_session(:migration_workbook_name, upload.filename)
      |> render(
        :validation,
        auth_assigns(conn) ++
          [
            validation: validation,
            filename: upload.filename
          ]
      )
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, validation_error_message(reason))
        |> redirect(to: ~p"/admin/migration")
    end
  end

  defp store_workbook(upload) do
    directory =
      Path.join(System.tmp_dir!(), "fluffy_web_migrations")

    with :ok <- File.mkdir_p(directory),
         :ok <- File.chmod(directory, 0o700) do
      token =
        24
        |> :crypto.strong_rand_bytes()
        |> Base.url_encode64(padding: false)

      destination = Path.join(directory, "#{token}.xlsx")

      case File.cp(upload.path, destination) do
        :ok ->
          case File.chmod(destination, 0o600) do
            :ok -> {:ok, destination}
            {:error, reason} ->
              File.rm(destination)
              {:error, {:copy_failed, reason}}
          end

        {:error, reason} ->
          {:error, {:copy_failed, reason}}
      end
    end
  end

  defp validation_error_message({:invalid_workbook, reason}) do
    "The uploaded file could not be read as an Excel workbook: #{reason}"
  end

  defp validation_error_message({:copy_failed, reason}) do
    "The workbook could not be stored for migration: #{inspect(reason)}"
  end

  defp validation_error_message(reason) do
    "Workbook validation failed: #{inspect(reason)}"
  end

  defp admin_email(conn) do
    profile = get_session(conn, :profile) || %{}
    profile[:email] || profile["email"] || ""
  end

  defp auth_assigns(conn) do
    [
      drive_connected: DriveAuth.connected?(get_session(conn, :drive_migration_token_id), admin_email(conn)),
      profile: get_session(conn, :profile),
      role: get_session(conn, :role),
      oauth_url: ElixirAuthGoogle.generate_oauth_url(FluffyWeb.Endpoint.url())
    ]
  end
end
