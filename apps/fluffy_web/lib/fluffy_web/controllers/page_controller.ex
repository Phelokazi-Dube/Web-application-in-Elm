defmodule FluffyWeb.PageController do
  require Logger
  alias FluffyWeb.MongoDBController
  alias WaterWeeds.MongoDBClient
  use FluffyWeb, :controller

  def home(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def upload(conn, params) do
    photos = params["photos"] || []

    # Process the photos and get their file IDs or any metadata
    processed_photos =
      Enum.map(photos, fn %Plug.Upload{
                            path: file_path,
                            filename: filename,
                            content_type: content_type
                          } ->
        case File.read(file_path) do
          {:ok, binary_data} ->
            # Log and upload the image with the appropriate metadata
            Logger.debug("Uploading photo: #{filename}, content_type: #{content_type}")

            case MongoDBClient.upload_image(filename, binary_data, %{content_type: content_type}) do
              {:ok, file_id} ->
                # Inspect and return the ObjectId of the uploaded image
                file_id |> IO.inspect(label: "Uploaded photo ObjectId")
                BSON.ObjectId.encode!(file_id)

              {:error, reason} ->
                Logger.error("Failed to upload photo: #{inspect(reason)}")
                nil
            end

          {:error, reason} ->
            Logger.error("Failed to read photo file: #{inspect(reason)}")
            nil
        end
      end)
      # Filter out any failed uploads (nil values)
      |> Enum.filter(&(&1 != nil))
      |> IO.inspect(label: "Processed photo ObjectIds")

    # Remove the CSRF token from the params (it should not be inserted into the database)
    cleaned_params = Map.delete(params, "_csrf_token")
    # Insert the survey data along with processed photo IDs into the "Surveys" collection
    cleaned_params = Map.put(cleaned_params, "photos", processed_photos)

    case MongoDBClient.insert_document("Surveys", cleaned_params) do
      {:ok, %{inserted_id: bson_id}} ->
        # Inspect the document ID after insertion
        bson_id |> IO.inspect(label: "Document stored with ID")
        Logger.debug("Document successfully inserted.")

        conn
        |> put_status(:ok)
        |> render(:home,
          layout: false,
          js_file: "uploading_data",
          extra_prepend:
            "The observation has been uploaded.  You can add another observation below."
        )

      {:error, reason} ->
        # Inspect the error reason if the insertion fails
        reason |> IO.inspect(label: "Insertion error reason")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create document", reason: reason})
    end
  end

  def uploading(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def sites(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def contact(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def publish(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def downloading(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def survey(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def upload_csv(conn, params) do
    MongoDBClient.insert_many_documents("Sana", Map.delete(params, "csrf_token"))
    # Expected: the _id of the new document.
    |> IO.inspect(label: "Documents stored with ID")

    conn
    |> put_status(:ok)
    |> render(:home,
      layout: false,
      js_file: "map",
      extra_prepend: "The CSV file has been successfully uploaded"
    )
  end

  def map(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end
end
