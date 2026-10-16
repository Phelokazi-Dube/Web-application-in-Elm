defmodule FluffyWeb.MongoDBController do
  require Logger
  alias FluffyWeb.ControllerHelpers
  alias WaterWeeds.MongoDBClient
  alias WaterWeeds.DataNormalizer
  use FluffyWeb, :controller

  # Collections recognised by FluffyWeb
  @allowed_collections ~w(
    Surveys SurveyWeedAgent Sites SiteInspections SiteInspectionWeeds Locations
    Districts Regions Continents Countries Implementers Programs WeedNames Users
    ControlAgents SurveyControlAgents WHMCounter WHMeasurements WHMeasurementReadings BAR
  )

  # Collections that must not be exposed through public API endpoints
  @private_collections ~w(
    Users
    Implementers
    WHMCounter
  )

  # Stable identities used to prevent duplicate records during CSV uploads.
  # Collections are included only where a safe identity has been established.
  @csv_identities %{
    "Surveys" => ["surveyId"],
    "SurveyWeedAgent" => ["swaid"],
    "SiteInspections" => ["siteInspectionId"],
    "SiteInspectionWeeds" => ["siteInspectionWeedId"],
    "Locations" => ["locationId"],
    "Districts" => ["districtId"],
    "Regions" => ["regionId"],
    "Continents" => ["continentId"],
    "Countries" => ["countryId", "continentId"],
    "Implementers" => ["implementerId"],
    "WeedNames" => ["weedId"],
    "ControlAgents" => ["controlAgentId"],
    "SurveyControlAgents" => ["id"],
    "WHMeasurements" => ["whmid"],
    "BAR" => ["barId"]
  }

  defp validate_collection_access(conn, collection) do
    cond do
      collection not in @allowed_collections ->
        {:error, :invalid_collection}

      collection in @private_collections and get_session(conn, :role) != "admin" ->
        {:error, :forbidden}

      true ->
        :ok
    end
  end

  defp collection_access_error(conn, :invalid_collection) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid collection"})
  end

  defp collection_access_error(conn, :forbidden) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "You are not authorized to access this collection"})
  end


  @protected_fields ~w(
    _id id collection
    userLogin
    approved approved_by approved_at
    created_at updated_at updated_by
    date_dt geospatialCoordinates
    photos publications
  )

  defp prepare_edit_changes(params, existing, collection) do
    identity_fields = Map.get(@csv_identities, collection, [])

    protected_fields =
      @protected_fields ++
        identity_fields ++
        ["_csrf_token", "_method"]

    params
    |> Map.drop(protected_fields)
    |> Enum.reduce_while({:ok, %{}}, fn {field, submitted}, {:ok, changes} ->
      case Map.fetch(existing, field) do
        {:ok, old_value} ->
          case cast_edit_value(field, submitted, old_value) do
            {:ok, new_value} ->
              if new_value == old_value do
                {:cont, {:ok, changes}}
              else
                {:cont, {:ok, Map.put(changes, field, new_value)}}
              end

            {:error, reason} ->
              {:halt, {:error, {field, reason}}}
          end
        :error ->
          if collection in ["Surveys", "Locations"] and
              field in ["latitude", "longitude"] and
              is_binary(submitted) and
              String.trim(submitted) != "" do
            {:cont, {:ok, Map.put(changes, field, submitted)}}
          else
            # Ignore arbitrary new fields and blank coordinate inputs.
            {:cont, {:ok, changes}}
          end
      end
    end)
  end

  defp cast_edit_value(field, value, _old)
      when field in ["date", "year"] and
              is_binary(value) and value == "" do
    {:ok, ""}
  end

  defp cast_edit_value(field, value, _old)
    when field in ["latitude", "longitude"] and is_binary(value) do
      {:ok, String.trim(value)}
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_boolean(old) do
    case value do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, :invalid_boolean}
    end
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_integer(old) do
    case Integer.parse(String.trim(value)) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid_integer}
    end
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_list(old) do
    case Jason.decode(value) do
      {:ok, decoded} when is_list(decoded) ->
        {:ok, decoded}

      _ ->
        {:error, :invalid_json_list}
    end
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_float(old) do
    case Float.parse(String.trim(value)) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_map(old) do
    case Jason.decode(value) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _ -> {:error, :invalid_json}
    end
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_list(old) do
    # Only simple string lists can safely use the
    # comma-separated textarea in the existing form.
    if Enum.all?(old, &is_binary/1) do
      parsed =
        if String.trim(value) == "" do
          []
        else
          value
          |> String.split(",")
          |> Enum.map(&String.trim/1)
      end

      {:ok, parsed}
    else
      {:error, :unsupported_list}
    end
  end

  defp cast_edit_value(_field, value, nil) when is_binary(value) do
    if String.trim(value) == "" do
      {:ok, nil}
    else
      {:ok, value}
    end
  end

  defp cast_edit_value(_field, value, old)
      when is_binary(value) and is_binary(old) do
    {:ok, value}
  end

  defp cast_edit_value(_field, value, old) do
    if value == old do
      {:ok, old}
    else
      {:error, :unsupported_field_type}
    end
  end

  defp normalize_edit_changes(changes, existing) do
    with {:ok, located} <- normalize_edit_coordinates(changes, existing),
       {:ok, dated, unset_fields} <- normalize_edit_date(located, existing) do
      # Normalisation can produce an equivalent value.
      # Remove those from the actual change set.
      actual_changes =
        Map.reject(dated, fn {field, value} ->
          Map.has_key?(existing, field) and existing[field] == value
        end)

      actual_unsets =
        Enum.filter(unset_fields, &Map.has_key?(existing, &1))

      {:ok, actual_changes, actual_unsets}
    end
  end

  defp normalize_edit_coordinates(changes, existing) do
    coordinates_changed? =
      Map.has_key?(changes, "latitude") or
        Map.has_key?(changes, "longitude")

    if coordinates_changed? do
      effective =
        %{}
        |> include_effective_field("latitude", changes, existing)
        |> include_effective_field("longitude", changes, existing)

      case ControllerHelpers.normalize_location(effective) do
        {:ok, %{"geospatialCoordinates" => point}} ->
          {:ok, Map.put(changes, "geospatialCoordinates", point)}

        {:ok, _} ->
          {:error, :incomplete_coordinates}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, changes}
    end
  end

  defp normalize_edit_date(changes, existing) do
    date_changed? = Map.has_key?(changes, "date")
    year_changed? = Map.has_key?(changes, "year")

    if date_changed? or year_changed? do
      effective =
        %{}
        |> include_effective_field("date", changes, existing)
        |> include_effective_field("year", changes, existing)

      case ControllerHelpers.normalize_date(effective) do
        {:ok, normalized} ->
          date_dt = Map.fetch(normalized, "date_dt")

          case date_dt do
            {:ok, value} ->
              {:ok, Map.put(changes, "date_dt", value), []}

            :error ->
              {:ok, changes, []}
          end

        {:ok, _normalized, :clear_date_dt} ->
          {:ok, Map.delete(changes, "date_dt"), ["date_dt"]}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, changes, []}
    end
  end

  defp include_effective_field(result, field, changes, existing) do
    cond do
      Map.has_key?(changes, field) ->
        Map.put(result, field, changes[field])

      Map.has_key?(existing, field) ->
        Map.put(result, field, existing[field])

      true ->
        result
    end
  end

  defp uploaded_files(nil), do: []

  defp uploaded_files(%Plug.Upload{} = upload), do: [upload]

  defp uploaded_files(uploads) when is_list(uploads), do: uploads

  defp uploaded_files(uploads) when is_map(uploads),
    do: Map.values(uploads)

  defp uploaded_files(_), do: []


  defp prepare_survey_attachments(params) do
    photos = uploaded_files(Map.get(params, "photos"))
    publications = uploaded_files(Map.get(params, "publications"))

    with :ok <- validate_uploads(photos, :photo),
        :ok <- validate_uploads(publications, :publication) do
      {:ok, photos, publications}
    end
  end


  defp validate_uploads(uploads, type) do
    Enum.reduce_while(uploads, :ok, fn
      %Plug.Upload{} = upload, :ok ->
        case validate_upload(upload, type) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _, :ok ->
        {:halt, {:error, :invalid_upload}}
    end)
  end


  defp validate_upload(%Plug.Upload{} = upload, type) do
    allowed_types =
      case type do
        :photo ->
          ["image/jpeg", "image/png", "image/gif", "image/webp"]

        :publication ->
          ["application/pdf"]
      end

    with true <- upload.content_type in allowed_types,
        {:ok, %{size: size}} <- File.stat(upload.path),
        true <- size > 0,
        {:ok, file} <- File.open(upload.path, [:read, :binary]) do
      header = IO.binread(file, 16)
      File.close(file)

      if valid_file_signature?(header, type) do
        :ok
      else
        {:error, :invalid_file_content}
      end
    else
      false -> {:error, :invalid_file_type_or_size}
      {:error, reason} -> {:error, reason}
    end
  end


  defp valid_file_signature?(<<"%PDF-", _::binary>>, :publication),
    do: true

  defp valid_file_signature?(<<0xFF, 0xD8, 0xFF, _::binary>>, :photo),
    do: true

  defp valid_file_signature?(<<0x89, "PNG", 13, 10, 26, 10, _::binary>>, :photo),
    do: true

  defp valid_file_signature?(<<"GIF87a", _::binary>>, :photo),
    do: true

  defp valid_file_signature?(<<"GIF89a", _::binary>>, :photo),
    do: true

  defp valid_file_signature?(<<"RIFF", _size::binary-size(4), "WEBP", _::binary>>, :photo),
    do: true

  defp valid_file_signature?(_, _), do: false


  defp upload_survey_attachments(photos, publications) do
    with {:ok, photo_ids} <- upload_files(photos, :photo),
        {:ok, publication_ids} <- upload_files(publications, :publication) do
      {:ok, photo_ids, publication_ids}
    end
  end


  defp upload_files(uploads, type) do
    Enum.reduce_while(uploads, {:ok, []}, fn upload, {:ok, ids} ->
      with {:ok, binary_data} <- File.read(upload.path),
          {:ok, file_id} <- store_attachment(upload, binary_data, type) do
        {:cont, {:ok, [BSON.ObjectId.encode!(file_id) | ids]}}
      else
        {:error, reason} ->
          {:halt, {:error, {:attachment_upload_failed, reason}}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, Enum.reverse(ids)}
      error -> error
    end
  end


  defp store_attachment(upload, binary_data, :photo) do
    MongoDBClient.upload_image(
      upload.filename,
      binary_data,
      %{content_type: upload.content_type}
    )
  end


  defp store_attachment(upload, binary_data, :publication) do
    MongoDBClient.upload_file(
      upload.filename,
      binary_data,
      %{
        content_type: upload.content_type,
        type: "publication"
      }
    )
  end


  defp append_attachment_ids(changes, existing, field, new_ids) do
    if new_ids == [] do
      changes
    else
      existing_ids =
        case Map.get(existing, field) do
          nil -> []
          ids when is_list(ids) -> ids
        end

      Map.put(changes, field, existing_ids ++ new_ids)
    end
  end

  # Implement Jason.Encoder for BSON.ObjectId
  defimpl Jason.Encoder, for: BSON.ObjectId do
    def encode(value, opts) do
      Jason.Encode.string(BSON.ObjectId.encode!(value), opts)
    end
  end

  @spec all(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def all(conn, %{"collection" => collection}) do
    # Ensure only allowed collections are queried
    case validate_collection_access(conn, collection) do
      :ok ->
          documents = MongoDBClient.get_all_documents(collection)
          isAdmin = get_session(conn, :role) == "admin"

          conn
          |> put_status(:ok)
          |> json(%{isAdmin: isAdmin, documents: documents})
      end
  end

  def all(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing collection parameter"})
  end

  def search(conn, %{"search" => search_text} = params) do
    collection = Map.get(params, "collection", "Surveys")

    case validate_collection_access(conn, collection) do
    :ok ->
      documents =
        if String.trim(search_text) == "" do
          MongoDBClient.get_all_documents(collection)
        else
          MongoDBClient.search_documents_by_text(collection, search_text)
        end

      isAdmin = get_session(conn, :role) == "admin"

      conn
      |> put_status(:ok)
      |> json(%{
        isAdmin: isAdmin,
        documents: documents
      })

      {:error, reason} ->
        collection_access_error(conn, reason)
    end
  end

  # Fetch a document by its ID
  def show(conn, %{"id" => id, "collection" => collection}) do
    collection = collection || "Surveys"

    case validate_collection_access(conn, collection) do
      :ok ->
      with {:ok, bson_id} <- BSON.ObjectId.decode(id),
          doc when not is_nil(doc) <- MongoDBClient.get_document_by_id(collection, bson_id) do
        normalized = ControllerHelpers.normalize_mongo_id(doc)
        json(conn, normalized)
      else
        {:error, _} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid document ID"})

        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Document not found"})
      end

      {:error, reason} ->
        collection_access_error(conn, reason)
    end
  end

  # Fetch a document as HTML
  def show_html(conn, %{"id" => id} = params) do
    collection = Map.get(params, "collection", "Surveys")

    case BSON.ObjectId.decode(id) do
      {:ok, bson_id} ->
        case MongoDBClient.get_document_by_id(collection, bson_id) do
          %{} = doc ->
            normalized = ControllerHelpers.normalize_mongo_id(doc)
            profile = get_session(conn, :profile)
            role = get_session(conn, :role)

            current_user_email =
              if profile do
                Map.get(profile, :email)
              else
                nil
              end

            owner_email = Map.get(normalized, "userLogin")

            can_edit =
              role == "admin" or
                (not is_nil(current_user_email) and current_user_email == owner_email)

            editing = params["edit"] == "true"

            oauth_url = ElixirAuthGoogle.generate_oauth_url(FluffyWeb.Endpoint.url())

            redirect_path =
              conn.request_path <>
                if conn.query_string != "" do
                  "?" <> conn.query_string
                else
                  ""
                end

            conn =
              put_session(
                conn,
                :redirect_after_login,
                redirect_path
              )

            cond do
              editing and is_nil(current_user_email) ->
                conn
                |> put_flash(:error, "You must be logged in to edit a document.")
                |> redirect(to: "/documents/#{id}?collection=#{collection}")

              editing and not can_edit ->
                conn
                |> put_status(:forbidden)
                |> put_flash(
                  :error,
                  "You are not authorised to edit this document."
                )
                |> redirect(to: "/documents/#{id}?collection=#{collection}")

              true ->
                template =
                  if editing do
                    :edit
                  else
                    :show
                  end

                render(
                  conn,
                  template,
                  document: normalized,
                  document_id: id,
                  collection: collection,
                  profile: profile,
                  oauth_url: oauth_url,
                  can_edit: can_edit
                )
            end

          _ ->
            conn
            |> put_flash(:error, "Document not found")
            |> redirect(to: "/")
        end

      _ ->
        conn
        |> put_flash(:error, "Invalid document ID")
        |> redirect(to: "/")
    end
  end

  def get_image(conn, %{"id" => id}) do
    with {:ok, bson_id} <- BSON.ObjectId.decode(id),
         %{bucket: bucket} <- :sys.get_state(WaterWeeds.MongoDBClient),
         {{:ok, stream}, file_doc} <- Mongo.GridFs.Download.find_and_stream(bucket, bson_id) do
      content_type =
        case Path.extname(file_doc["filename"]) do
          ".jpg" -> "image/jpeg"
          ".jpeg" -> "image/jpeg"
          ".png" -> "image/png"
          ".gif" -> "image/gif"
          _ -> "application/octet-stream"
        end

      conn =
        conn
        |> put_resp_content_type(content_type)
        |> send_chunked(200)

      stream_chunks(conn, stream)
    else
      _ -> send_resp(conn, 404, "Image not found")
    end
  end

  def get_publication(conn, %{"id" => id}) do
    with {:ok, bson_id} <- BSON.ObjectId.decode(id),
         %{bucket: bucket} <- :sys.get_state(WaterWeeds.MongoDBClient),
         {{:ok, stream}, file_doc} <-
           Mongo.GridFs.Download.find_and_stream(bucket, bson_id) do
      content_type =
        case Path.extname(file_doc["filename"]) do
          ".pdf" ->
            "application/pdf"

          ".doc" ->
            "application/msword"

          ".docx" ->
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

          _ ->
            "application/octet-stream"
        end

      conn =
        conn
        |> put_resp_header(
          "content-disposition",
          ~s(inline; filename="#{file_doc["filename"]}")
        )
        |> put_resp_content_type(content_type)
        |> send_chunked(200)

      stream_chunks(conn, stream)
    else
      _ ->
        send_resp(conn, 404, "Publication not found")
    end
  end

  defp stream_chunks(conn, stream) do
    Enum.reduce_while(stream, conn, fn chunk, conn_acc ->
      case Plug.Conn.chunk(conn_acc, chunk) do
        {:ok, conn_acc} -> {:cont, conn_acc}
        {:error, _} -> {:halt, conn_acc}
      end
    end)
  end

  # Action to upload and process a CSV file with dynamic fields
  @spec upload_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def upload_csv(conn, %{"file" => %Plug.Upload{path: file_path}, "collection" => collection}) do
    conn = fetch_session(conn)
    profile = get_session(conn, :profile)
    email = profile && Map.get(profile, :email)

    cond do
      collection not in @allowed_collections ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid collection"})

      is_nil(email) ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated"})

      not Map.has_key?(@csv_identities, collection) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error:
            "CSV upload is not available for #{collection} because a safe record identity has not been configured."
        })

      true ->
        process_csv_upload(conn, file_path, collection, email)
    end
  end

  defp process_csv_upload(conn, file_path, collection, email) do
    if File.stat!(file_path).size == 0 do
      conn
      |> put_status(:bad_request)
      |> render("upload_empty.html",
        message: "CSV file is empty",
        collection: collection
      )
    else
      identity_fields = Map.fetch!(@csv_identities, collection)
      documents =
        file_path
        |> File.stream!()
        |> CSV.decode(separator: ?,, headers: true)
        |> Enum.flat_map(fn
          {:ok, row} ->
            document =
              row
              |> ControllerHelpers.normalize_keys()
              |> Map.drop(@protected_fields -- identity_fields)
              |> ControllerHelpers.add_date_dt()

            [document]

          {:error, reason} ->
            Logger.warning("Skipping invalid CSV row: #{inspect(reason)}")
            []
        end)

      cond do
        documents == [] ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "No valid data found in CSV"})

        true ->
          case normalize_csv_documents(documents, collection) do
            {:ok, normalized_documents} ->
              upsert_csv_documents(conn, collection, normalized_documents, email)

            {:error, {:invalid_id, row_number, field, reason}} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{
                error: "Invalid CSV identifier",
                row: row_number,
                field: field,
                reason: inspect(reason)
              })
          end
      end
    end
  end

  defp upsert_csv_documents(conn, collection, documents, email) do
    identity_fields = Map.fetch!(@csv_identities, collection)

    with :ok <- validate_csv_identities(documents, identity_fields),
     :ok <- validate_unique_csv_identities(documents, identity_fields),
     :ok <- validate_database_csv_identities(collection, documents, identity_fields) do
      case MongoDBClient.transaction(fn mongo_conn ->
            perform_csv_upserts(
              mongo_conn,
              collection,
              documents,
              identity_fields,
              email
            )
          end) do
        {:ok, counts} ->
          processed_count =
            counts.inserted + counts.updated + counts.unchanged

          Logger.info(
            "Processed #{processed_count} CSV documents for #{collection}"
          )

          conn
          |> put_status(:created)
          |> render("upload_success.html",
            message: "Upload successful",
            collection: collection,
            processed_count: processed_count
          )

        {:error, reason} ->
          Logger.error("Failed to process CSV: #{inspect(reason)}")

          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            error: "Failed to process CSV",
            reason: inspect(reason)
          })
      end
    else
      {:error, {:duplicate_csv_identities, identities}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Duplicate identities found in CSV",
          message:
            "The CSV contains multiple rows with the same identity. Please correct the file and upload it again.",
          collection: collection,
          duplicate_identities: identities
        })

      {:error, {:ambiguous_database_identities, identities}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "CSV upload rejected because duplicate records exist in the database.",
          message:
            "No records were changed. Please resolve the duplicate database records and upload the CSV again.",
          collection: collection,
          duplicate_identities: identities
        })

      {:error, missing_fields} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("upload_error.html",
          title: "CSV Does Not Match This Collection",
          message:
            "This file does not appear to contain the required fields for #{collection}. Please check that you selected the correct CSV file.",
          collection: collection,
          required_fields: identity_fields,
          missing_fields: missing_fields
        )
    end
  end

  defp validate_csv_identities(documents, identity_fields) do
    missing_fields =
      documents
      |> Enum.flat_map(fn document ->
        Enum.filter(identity_fields, fn field ->
          value = Map.get(document, field)

          is_nil(value) or
            (is_binary(value) and String.trim(value) == "")
        end)
      end)
      |> Enum.uniq()

    case missing_fields do
      [] -> :ok
      fields -> {:error, fields}
    end
  end

  defp validate_unique_csv_identities(documents, identity_fields) do
    duplicates =
      documents
      |> Enum.group_by(&Map.take(&1, identity_fields))
      |> Enum.filter(fn {_identity, rows} -> length(rows) > 1 end)
      |> Enum.map(fn {identity, _rows} -> identity end)

    case duplicates do
      [] -> :ok
      identities -> {:error, {:duplicate_csv_identities, identities}}
    end
  end

  defp validate_database_csv_identities(collection, documents, identity_fields) do
    ambiguous_identities =
      documents
      |> Enum.map(fn document ->
        identity = Map.take(document, identity_fields)

        case MongoDBClient.get_all_documents(collection, identity) do
          [_first, _second | _rest] -> identity
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    case ambiguous_identities do
      [] -> :ok
      identities -> {:error, {:ambiguous_database_identities, identities}}
    end
  end

  defp perform_csv_upserts( mongo_conn, collection, documents, identity_fields, email) do
    Enum.reduce_while(documents, {:ok, %{inserted: 0, updated: 0, unchanged: 0}}, fn document, {:ok, counts} ->
      filter = Map.take(document, identity_fields)

      case Mongo.find(mongo_conn, collection, filter) |> Enum.to_list() do
        [] ->
          now = System.os_time(:second)

          new_document =
            document
            |> DataNormalizer.prepare_coordinates(nil)
            |> Map.put("userLogin", email)
            |> Map.put("approved", false)
            |> Map.put("approved_by", nil)
            |> Map.put("approved_at", nil)
            |> Map.put("created_at", now)

          case Mongo.insert_one(mongo_conn, collection, new_document) do
            {:ok, _result} ->
              {:cont, {:ok, Map.update!(counts, :inserted, &(&1 + 1))}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        [existing] ->
          document = DataNormalizer.prepare_coordinates(document, existing)

          changes =
            Map.reject(document, fn {field, value} ->
              Map.has_key?(existing, field) and
                Map.get(existing, field) == value
            end)

          if map_size(changes) == 0 do
            {:cont, {:ok, Map.update!(counts, :unchanged, &(&1 + 1))}}
          else
            update_fields =
              Map.merge(changes, %{
                "approved" => false,
                "approved_by" => nil,
                "approved_at" => nil,
                "updated_by" => email,
                "updated_at" => System.os_time(:second)
              })

              case Mongo.update_one(
                mongo_conn,
                collection,
                %{"_id" => existing["_id"]},
                %{"$set" => update_fields}
              ) do
              {:ok, _updated_document} ->
                {:cont, {:ok, Map.update!(counts, :updated, &(&1 + 1))}}

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          end

        [_first, _second | _rest] ->
          {:halt, {:error, {:ambiguous_identity, filter}}}
      end
    end)
  end

  defp normalize_csv_documents(documents, collection) do
    documents
    |> Enum.with_index(2)
    |> Enum.reduce_while({:ok, []}, fn {document, row_number}, {:ok, acc} ->
      case DataNormalizer.normalize_ids(document, collection) do
        {:ok, normalized} ->
          {:cont, {:ok, [normalized | acc]}}

        {:error, {field, reason}} ->
          {:halt, {:error, {:invalid_id, row_number, field, reason}}}
      end
    end)
    |> case do
      {:ok, normalized_documents} ->
        {:ok, Enum.reverse(normalized_documents)}

      error ->
        error
    end
  end

  def delete_document(conn, %{"id" => id, "collection" => collection}) do
    role = get_session(conn, :role)
    profile = get_session(conn, :profile)

    current_user_email =
      if profile do
        Map.get(profile, :email)
      else
        nil
      end

    case validate_collection_access(conn, collection) do
      :ok ->
        case BSON.ObjectId.decode(id) do
          {:ok, bson_id} ->
            case MongoDBClient.get_document_by_id(collection, bson_id) do
              nil ->
                conn
                |> put_flash(:error, "Document not found.")
                |> redirect(to: "/records")

              %{} = existing_document ->
                owner_email = Map.get(existing_document, "userLogin")

                can_delete =
                  role == "admin" or
                    (not is_nil(current_user_email) and
                      current_user_email == owner_email)

                if can_delete do
                  case MongoDBClient.delete_document(collection, bson_id) do
                    {:ok, _result} ->
                      conn
                      |> put_flash(:info, "Document deleted successfully.")
                      |> redirect(to: "/records")

                    {:error, reason} ->
                      Logger.error(
                        "Failed to delete document #{id} from #{collection}: #{inspect(reason)}"
                      )

                      conn
                      |> put_flash(:error, "Failed to delete document.")
                      |> redirect(to: "/documents/#{id}?collection=#{collection}")
                  end
                else
                  conn
                  |> put_status(:forbidden)
                  |> put_flash(
                    :error,
                    "You are not authorised to delete this document."
                  )
                  |> redirect(to: "/documents/#{id}?collection=#{collection}")
                end
            end

          :error ->
            conn
            |> put_flash(:error, "Invalid document ID.")
            |> redirect(to: "/records")
        end

      {:error, reason} ->
        collection_access_error(conn, reason)
    end
  end

  def to_rhodes(conn, _params) do
    redirect(conn, external: "https://www.ru.ac.za/centreforbiologicalcontrol/")
  end

  def to_calendar(conn, _params) do
    redirect(conn,
      external:
        "https://calendar.google.com/calendar/embed?src=phelokazidube%40gmail.com&ctz=Africa%2FJohannesburg"
    )
  end

  def to_annual_reports(conn, _params) do
    redirect(conn,
      external: "https://www.ru.ac.za/centreforbiologicalcontrol/resources/annualreports"
    )
  end

  def to_publications(conn, _params) do
    redirect(conn,
      external: "https://www.ru.ac.za/centreforbiologicalcontrol/resources/publications"
    )
  end

  def to_news(conn, _params) do
    redirect(conn,
      external: "https://www.ru.ac.za/centreforbiologicalcontrol/latestnews"
    )
  end

  def to_facebook(conn, _params) do
    redirect(conn,
      external: "https://www.facebook.com/RhodesUniCBC"
    )
  end

  def to_linkedin(conn, _params) do
    redirect(conn,
      external: "https://www.linkedin.com/company/centre-for-biological-control"
    )
  end

  def to_instagram(conn, _params) do
    redirect(conn,
      external: "https://www.instagram.com/rhodesunicbc"
    )
  end

  def to_x(conn, _params) do
    redirect(conn,
      external: "https://x.com/RhodesUniCBC"
    )
  end

  # Function that approves the documents
  def approve(conn, %{"id" => id} = params) do
    role = get_session(conn, :role) || "user"
    profile = get_session(conn, :profile)
    admin_email = profile && Map.get(profile, :email)
    collection = Map.get(params, "collection", "Surveys")

    cond do
      collection not in @allowed_collections ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid collection"})

      role != "admin" or is_nil(admin_email) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only admins can approve documents"})

      true ->
        case BSON.ObjectId.decode(id) do
          {:ok, bson_id} ->
            update_fields = %{
              "approved" => true,
              "approved_by" => admin_email,
              "approved_at" => System.os_time(:second)
            }

            case MongoDBClient.update_document(
                   collection,
                   bson_id,
                   update_fields
                 ) do
              {:ok, updated_doc} ->
                document = ControllerHelpers.normalize_mongo_id(updated_doc)

                conn
                |> put_status(:ok)
                |> json(%{
                  message: "Document approved successfully",
                  document: document
                })

              {:error, reason} ->
                Logger.error("Failed to approve document: #{inspect(reason)}")

                conn
                |> put_status(:unprocessable_entity)
                |> json(%{
                  error: "Failed to approve document",
                  reason: inspect(reason)
                })
            end

          :error ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Invalid ID format"})
        end
    end
  end

  # Safer update_document
  def update_document(conn, %{"id" => id, "collection" => collection} = params) do
    role = get_session(conn, :role)
    profile = get_session(conn, :profile)

    current_user_email =
      if profile, do: Map.get(profile, :email), else: nil

    show_path = ~p"/documents/#{id}?collection=#{collection}"
    edit_path = show_path <> "&edit=true"

    cond do
      collection not in @allowed_collections ->
        conn
        |> put_flash(:error, "Invalid collection.")
        |> redirect(to: "/")

      collection in @private_collections and role != "admin" ->
        conn
        |> put_flash(:error, "You are not authorised to edit this collection.")
        |> redirect(to: "/")

      true ->
        case BSON.ObjectId.decode(id) do
          {:ok, bson_id} ->
            case MongoDBClient.get_document_by_id(collection, bson_id) do
              nil ->
                conn
                |> put_flash(:error, "Document not found.")
                |> redirect(to: "/")

              %{} = existing_document ->
                owner_email = Map.get(existing_document, "userLogin")

                can_edit =
                  role == "admin" or
                    (not is_nil(current_user_email) and
                      current_user_email == owner_email)

                if can_edit do
                  with {:ok, changes} <-
                        prepare_edit_changes(
                          params,
                          existing_document,
                          collection
                        ),
                      {:ok, normalized, unset_fields} <-
                        normalize_edit_changes(changes, existing_document),
                      {:ok, photos, publications} <-
                        prepare_survey_attachments(
                          if(collection == "Surveys", do: params, else: %{})
                        ) do

                    attachments_selected? =
                      photos != [] or publications != []

                    if map_size(normalized) == 0 and
                        unset_fields == [] and
                        not attachments_selected? do
                      conn
                      |> put_flash(:info, "No changes were made.")
                      |> redirect(to: show_path)
                    else
                      case upload_survey_attachments(photos, publications) do
                        {:ok, photo_ids, publication_ids} ->
                          updated_changes =
                            normalized
                            |> append_attachment_ids(
                              existing_document,
                              "photos",
                              photo_ids
                            )
                            |> append_attachment_ids(
                              existing_document,
                              "publications",
                              publication_ids
                            )

                          update_fields =
                            Map.merge(updated_changes, %{
                              "approved" => false,
                              "approved_by" => nil,
                              "approved_at" => nil,
                              "updated_by" => current_user_email,
                              "updated_at" => System.os_time(:second)
                            })

                          case MongoDBClient.update_document_fields(
                                collection,
                                bson_id,
                                update_fields,
                                unset_fields
                              ) do
                            {:ok, _updated_document} ->
                              conn
                              |> put_flash(
                                :info,
                                "Document updated successfully. It is awaiting re-approval."
                              )
                              |> redirect(to: show_path)

                            {:error, reason} ->
                              Logger.error(
                                "Failed to update document: #{inspect(reason)}"
                              )

                              conn
                              |> put_flash(:error, "Failed to update document.")
                              |> redirect(to: edit_path)
                          end

                        {:error, reason} ->
                          Logger.error(
                            "Failed to upload attachments: #{inspect(reason)}"
                          )

                          conn
                          |> put_flash(
                            :error,
                            "Failed to upload attachments. No document changes were saved."
                          )
                          |> redirect(to: edit_path)
                      end
                    end
                  else
                    {:error, reason} ->
                      Logger.warning(
                        "Invalid document edit: #{inspect(reason)}"
                      )

                      conn
                      |> put_flash(
                        :error,
                        "Invalid field value or attachment. Please check your changes."
                      )
                      |> redirect(to: edit_path)
                  end
                else
                  conn
                  |> put_status(:forbidden)
                  |> put_flash(
                    :error,
                    "You are not authorised to edit this document."
                  )
                  |> redirect(to: show_path)
                end
            end

          :error ->
            conn
            |> put_flash(:error, "Invalid document ID.")
            |> redirect(to: "/")
        end
    end
  end

  # Function to fetch unapproved documents
  def unapproved(conn, _params) do
    documents = MongoDBClient.get_all_documents("Surveys", %{"approved" => false})

    # Return the documents as JSON
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  # Function to fetch approved documents
  def approved(conn, _params) do
    documents = MongoDBClient.get_all_documents("Surveys", %{"approved" => true})

    # Return the documents as JSON
    conn
    |> put_status(:ok)
    |> json(%{documents: documents})
  end

  @spec export_search_csv(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def export_search_csv(conn, params) do
    search = Map.get(params, "search", "")
    collection = Map.get(params, "collection", "Surveys")

    case validate_collection_access(conn, collection) do
    :ok ->
      csv = WaterWeeds.MongoDBClient.export(collection, search)

      filename =
        collection
        |> String.downcase()
        |> Kernel.<>(".csv")

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="#{filename}")
      )
      |> send_resp(200, csv)

   {:error, reason} ->
      collection_access_error(conn, reason)
  end
  end
end
