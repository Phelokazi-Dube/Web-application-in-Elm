defmodule FluffyWeb.PageController do
  require Logger
  alias WaterWeeds.MongoDBClient
  use FluffyWeb, :controller

  def home(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false,conn: conn, js_file: conn.private[:javascript], profile: get_session(conn, :profile), oauth_url: ElixirAuthGoogle.generate_oauth_url(conn))
  end

  def upload(conn, params) do
    photos_param = params["photos"] || []
    profile = get_session(conn, :profile)
    user_email = if profile, do: Map.get(profile, :email), else: nil

    # Process the photos and get their file IDs or any metadata
    photos =
      cond do
        is_list(photos_param) ->
          photos_param
        match?(%Plug.Upload{}, photos_param) -> [photos_param]
        is_map(photos_param) ->
          photos_param
          |> Map.values()

        true ->
          []
      end
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
                IO.inspect(file_id, label: "Uploaded photo ObjectId")
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
    cleaned_params =
      params
      |> Map.delete("_csrf_token")
      # Insert the survey data along with processed photo IDs into the "Surveys" collection
      |> Map.put("photos", processed_photos)
      |> Map.put("userLogin", user_email)
      |> FluffyWeb.MongoDBController.add_date_dt()
      |> FluffyWeb.MongoDBController.parse_location()

    if photos == [] and Map.get(cleaned_params, "location") in [nil, ""] do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Empty form submission not allowed"})
    else
      case MongoDBClient.insert_document("Surveys", cleaned_params) do
        {:ok, %{inserted_id: bson_id}} ->
          # Inspect the document ID after insertion
          IO.inspect(bson_id, label: "Document stored with ID")
          Logger.debug("Document successfully inserted.")

          conn
          |> put_status(:ok)
          |> render(:home,
            layout: false,
            js_file: "uploading_data",
            extra_prepend:
            ~s(The observation has been uploaded. You can add another observation below. Or you can return to the <a href="/uploadpage" class="text-blue-500 underline">upload page</a>.),
          profile: get_session(conn, :profile)
          )

        {:error, reason} ->
          # Inspect the error reason if the insertion fails
          IO.inspect(reason, label: "Insertion error reason")

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to create document", reason: reason})
      end
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

  def survey(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def uploadpage(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def index(conn, _params) do
    base_url = FluffyWeb.Endpoint.url()
    oauth_google_url = ElixirAuthGoogle.generate_oauth_url(base_url)
    render(conn, :home, layout: false, oauth_google_url: oauth_google_url, js_file: conn.private[:javascript])
  end

  def upload_csv(conn, params) do
    MongoDBClient.insert_many_documents("Surveys", Map.delete(params, "_csrf_token"))
    # Expected: the _id of the new document.
    |> IO.inspect(label: "Documents stored with ID")

    conn
    |> put_status(:ok)
    |> render(:upload_success,
      layout: false,
      js_file: "csvupload",
      extra_prepend: "The CSV file has been successfully uploaded"
    )
  end

  def csvupload(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def profile(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def help(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def records(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end

  def countries(conn, _params) do
    # This skips the "app" layout (and in fact, that layout has been removed from the layouts folder)
    render(conn, :home, layout: false, js_file: conn.private[:javascript])
  end
end
