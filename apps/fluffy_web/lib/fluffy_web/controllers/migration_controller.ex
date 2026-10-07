defmodule FluffyWeb.MigrationController do
  use FluffyWeb, :controller

  alias WaterWeeds.Migration.Importer

  def index(conn, _params) do
    render(conn, :index, auth_assigns(conn))
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
    if File.regular?(workbook_path) do
      case Importer.import(workbook_path) do
        {:ok, result} ->
          filename =
            get_session(conn, :migration_workbook_name) ||
              "CBC workbook"

          File.rm(workbook_path)

          conn
          |> delete_session(:migration_workbook_path)
          |> delete_session(:migration_workbook_name)
          |> render(
            :success,
            auth_assigns(conn) ++
              [
                filename: filename,
                result: result
              ]
          )

        {:error, {:validation_failed, validation}} ->
          render(
            conn,
            :validation,
            auth_assigns(conn) ++
              [
                filename:
                  get_session(conn, :migration_workbook_name) ||
                    "CBC workbook",
                validation: validation
              ]
          )

        {:error, reason} ->
          conn
          |> put_flash(
            :error,
            "The migration could not be completed: #{inspect(reason)}"
          )
          |> redirect(to: ~p"/admin/migration")
      end
    else
      conn
      |> delete_session(:migration_workbook_path)
      |> delete_session(:migration_workbook_name)
      |> put_flash(
        :error,
        "The validated workbook is no longer available. Please upload it again."
      )
      |> redirect(to: ~p"/admin/migration")
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

    with :ok <- File.mkdir_p(directory) do
      token =
        24
        |> :crypto.strong_rand_bytes()
        |> Base.url_encode64(padding: false)

      destination = Path.join(directory, "#{token}.xlsx")

      case File.cp(upload.path, destination) do
        :ok -> {:ok, destination}
        {:error, reason} -> {:error, {:copy_failed, reason}}
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

  defp auth_assigns(conn) do
    [
      profile: get_session(conn, :profile),
      role: get_session(conn, :role),
      oauth_url: ElixirAuthGoogle.generate_oauth_url(FluffyWeb.Endpoint.url())
    ]
  end
end
