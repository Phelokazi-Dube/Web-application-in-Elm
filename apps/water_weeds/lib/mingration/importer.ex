defmodule WaterWeeds.Migration.Importer do
  @moduledoc """
  Validates and imports supported CBC workbook data into MongoDB.

  This module defines the migration rules:which worksheets are supported,
  their destination MongoDB collections, and the identity fields used for idempotent upserts.
  """

  alias WaterWeeds.Migration.Workbook
  alias WaterWeeds.MongoDBClient
  alias WaterWeeds.DataNormalizer

  # Sites are excluded until CBC verifies conflicting site identifiers/coordinates.
  # WHMCounter and empty/unconfigured sheets are not imported.
  @import_config %{
    "Surveys" => %{collection: "Surveys", identity: ["surveyId"]},
    "SurveyImages" => %{collection: "SurveyImages",identity: ["surveyImageId"]},
    "SurveyWeedAgent" => %{collection: "SurveyWeedAgent",identity: ["swaid"]},
    "SiteInspections" => %{collection: "SiteInspections",identity: ["siteInspectionId"]},
    "SiteInspectionWeeds" => %{collection: "SiteInspectionWeeds",identity: ["siteInspectionWeedId"]},
    "Locations" => %{collection: "Locations",identity: ["locationId"]},
    "Municipalities" => %{collection: "Municipalities",identity: ["municipalId"]},
    "Districts" => %{collection: "Districts",identity: ["districtId"]},
    "Regions" => %{collection: "Regions",identity: ["regionId"]},
    "Countries" => %{collection: "Countries",identity: ["countryId", "continentId"]},
    "Continents" => %{collection: "Continents",identity: ["continentId"]},
    "Weednames" => %{collection: "WeedNames",identity: ["weedId"]},
    "ControlAgents" => %{collection: "ControlAgents",identity: ["controlAgentId"]},
    "SurveyControlAgents" => %{collection: "SurveyControlAgents",identity: ["id"]},
    "WHMeasurements" => %{collection: "WHMeasurements",identity: ["whmid"]},
    # CBC confirmed WHMID + PlantNumber as the identity of each reading.
    "WHMeasurementsReadings" => %{collection: "WHMeasurementsReadings", identity: ["whmid", "plantNumber"]},
    "BAR" => %{collection: "BAR",identity: ["barId"]},
    "Implementers" => %{collection: "Implementers",identity: ["implementerId"]}
  }

  def import_config, do: @import_config

  @doc """
  Validates all configured worksheets without writing anything to MongoDB.
  """
  def validate(file_path) do
    with {:ok, sheets} <- Workbook.sheets(file_path) do
      available_sheet_names =
        sheets
        |> Enum.map(& &1.name)
        |> MapSet.new()

      results =
        @import_config
        |> Enum.map(fn {sheet_name, config} ->
          validate_sheet(
            file_path,
            sheet_name,
            config,
            available_sheet_names
          )
        end)

      configured_sheet_names =
        @import_config
        |> Map.keys()
        |> MapSet.new()

      skipped_sheets =
        sheets
        |> Enum.reject(fn sheet ->
          MapSet.member?(configured_sheet_names, sheet.name)
        end)
        |> Enum.map(& &1.name)
        |> Enum.sort()

      {:ok,
      %{
        valid?: Enum.all?(results, & &1.valid?),
        sheets: Enum.sort_by(results, & &1.sheet),
        skipped_sheets: skipped_sheets
      }}
    end
  end

  @doc """
  Validates and imports all configured CBC workbook worksheets.

  No database writes are performed unless the complete workbook passes
  validation.
  """
  def import(file_path) do
    with {:ok, %{valid?: true} = validation} <- validate(file_path),
     :ok <- validate_database_identities(file_path),
     {:ok, results} <- import_validated_workbook(file_path) do
      {:ok,
      %{
        validation: validation,
        imported: results,
        total_processed:
          Enum.sum(Enum.map(results, & &1.processed_count))
      }}
    else
      {:ok, %{valid?: false} = validation} ->
        {:error, {:validation_failed, validation}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_validated_workbook(file_path) do
    @import_config
    |> Enum.sort_by(fn {sheet_name, _config} -> sheet_name end)
    |> Enum.reduce_while({:ok, []}, fn {sheet_name, config}, {:ok, results} ->
      case import_sheet(file_path, sheet_name, config) do
        {:ok, result} ->
          {:cont, {:ok, [result | results]}}

        {:error, reason} ->
          {:halt,
          {:error,
            {:import_failed,
            %{
              sheet: sheet_name,
              collection: config.collection,
              reason: reason,
              completed: Enum.reverse(results)
            }}}}
      end
    end)
    |> case do
      {:ok, results} ->
        {:ok, Enum.reverse(results)}

      error ->
        error
    end
  end

  defp import_sheet(file_path, sheet_name, config) do
    with {:ok, documents} <- Workbook.prepare_documents(file_path, sheet_name, config.collection) do
      # URLs are consumed only by the authorised photo-import phase. Do not
      # publish private Drive URLs through generic MongoDB collection APIs.
      stored_documents =
        if config.collection == "SurveyImages" do
          Enum.map(documents, &Map.delete(&1, "driveUrl"))
        else
          documents
        end

      upsert_documents(
        stored_documents,
        config.collection,
        config.identity,
        sheet_name
      )
    end
  end

  defp upsert_documents(documents, collection, identity_fields, sheet_name) do
    documents
    |> Enum.reduce_while(
      {:ok, %{inserted: 0, updated: 0, unchanged: 0}},
      fn document, {:ok, counts} ->
        filter = Map.take(document, identity_fields)

        case MongoDBClient.get_all_documents(collection, filter) do
          [] ->
            new_document =
              document
              |> DataNormalizer.prepare_coordinates(nil)
              |> Map.put("approved", false)

            case MongoDBClient.insert_document(collection, new_document) do
              {:ok, _result} ->
                {:cont,
                {:ok, Map.update!(counts, :inserted, &(&1 + 1))}}

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
              {:cont,
              {:ok, Map.update!(counts, :unchanged, &(&1 + 1))}}
            else
              # Approval policy for changed legacy records is still
              # awaiting confirmation from CBC.
              case MongoDBClient.update_document_fields(
                    collection,
                    existing["_id"],
                    changes
                  ) do
                {:ok, _updated_document} ->
                  {:cont,
                  {:ok, Map.update!(counts, :updated, &(&1 + 1))}}

                {:error, reason} ->
                  {:halt, {:error, reason}}
              end
            end

          [_first, _second | _rest] ->
            {:halt, {:error, {:ambiguous_identity, filter}}}
        end
      end
    )
    |> case do
      {:ok, counts} ->
        {:ok,
        %{
          sheet: sheet_name,
          collection: collection,
          processed_count:
            counts.inserted + counts.updated + counts.unchanged,
          inserted_count: counts.inserted,
          updated_count: counts.updated,
          unchanged_count: counts.unchanged
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_sheet(file_path, sheet_name, config, available_sheets) do
    if MapSet.member?(available_sheets, sheet_name) do
      case Workbook.prepare_documents(file_path, sheet_name, config.collection) do
        {:ok, documents} ->
          missing_identity_count =
            Enum.count(documents, fn document ->
              not valid_identity?(document, config.identity)
            end)

          duplicate_identity_count =
            duplicate_identity_count(documents, config.identity)

          %{
            sheet: sheet_name,
            collection: config.collection,
            identity: config.identity,
            document_count: length(documents),
            missing_identity_count: missing_identity_count,
            duplicate_identity_count: duplicate_identity_count,
            valid?:
              missing_identity_count == 0 and
                duplicate_identity_count == 0
          }

        {:error, reason} ->
          %{
            sheet: sheet_name,
            collection: config.collection,
            identity: config.identity,
            document_count: 0,
            missing_identity_count: 0,
            duplicate_identity_count: 0,
            valid?: false,
            error: reason
          }
      end
    else
      %{
        sheet: sheet_name,
        collection: config.collection,
        identity: config.identity,
        document_count: 0,
        missing_identity_count: 0,
        duplicate_identity_count: 0,
        valid?: false,
        error: :sheet_not_found
      }
    end
  end

  defp duplicate_identity_count(documents, identity_fields) do
    documents
    |> Enum.filter(&valid_identity?(&1, identity_fields))
    |> Enum.group_by(&Map.take(&1, identity_fields))
    |> Enum.count(fn {_identity, records} ->
      length(records) > 1
    end)
  end

  defp valid_identity?(document, identity_fields) do
    Enum.all?(identity_fields, fn field ->
      case Map.get(document, field) do
        nil -> false
        value when is_binary(value) -> String.trim(value) != ""
        _value -> true
      end
    end)
  end

  @doc """
  Checks whether workbook identities match multiple existing MongoDB documents.

  This performs database reads only. It does not import or modify documents.
  """
  def validate_database(file_path) do
    with {:ok, report} <- validate(file_path),
        true <- report.valid? do
      validate_database_identities(file_path)
    else
      false -> {:error, :invalid_workbook}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_database_identities(file_path) do
    @import_config
    |> Enum.reduce_while(:ok, fn {sheet_name, config}, :ok ->
      with {:ok, documents} <- Workbook.prepare_documents(file_path, sheet_name, config.collection) do
        ambiguous =
          documents
          |> Enum.map(fn document ->
            filter = Map.take(document, config.identity)

            case MongoDBClient.get_all_documents(config.collection, filter) do
              [_first, _second | _rest] -> filter
              _ -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        case ambiguous do
          [] ->
            {:cont, :ok}

          identities ->
            {:halt,
            {:error,
              {:ambiguous_database_identities,
              %{
                sheet: sheet_name,
                collection: config.collection,
                identities: identities
              }}}}
        end
      else
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
end
