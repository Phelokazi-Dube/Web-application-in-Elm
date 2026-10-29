defmodule FluffyWeb.QueryController do
  use FluffyWeb, :controller

  alias FluffyWeb.ControllerHelpers
  alias WaterWeeds.MongoDBClient

  # Identified two site IDs which refer to conflicting places.
  @conflicting_site_ids MapSet.new(~w(S22E031AD-01-01 S32E027CD-03-01))

  # A historical survey is referenced by surveyId, new form submissions have
  # only a MongoDB ObjectId. Both are valid Survey Details records.
  def survey_details(conn, %{"survey_id" => reference}) do
    case find_survey(reference) do
      {:ok, survey} ->
        survey_id = survey["surveyId"]
        {site, site_status} = find_site(survey["siteId"])
        location = find_related(site, "locationId", "Locations", "locationId")
        measurements = find_measurements(survey_id)

        survey_data =
          survey
          |> Map.take(~w(
            _id surveyId siteId year assessor percentCover percentDamage remarks
            surveyType date weed controlAgent weather province country site
            sitename notes description weeds otherWeeds approved
            hyacinthMeasurements numberStemsDamagedM2 otherAquatics dataCapturer
          ))
          |> ControllerHelpers.normalize_mongo_id()
          |> Map.put("coordinatesDisplay", coordinates_display(survey))

        # Old Windows paths are kept as metadata, never returned as public photo links.
        uploaded = attachment_links(survey["photos"], "/image/")
        historical =
          if is_map(get_session(conn, :profile)) do
            historical_gridfs_images(survey_id)
          else
            []
          end

        json(conn, %{
          survey: survey_data,
          siteStatus: site_status,
          site: selected_fields(site, ~w(siteName province waterBody latitude longitude locationId)),
          location: selected_fields(location, ~w(location locationId latitude longitude)),
          geography: geographic_context(site, location),
          controlAgents: find_control_agents(survey_id),
          weedAgentLinks: find_weed_agent_links(survey_id),
          measurements: measurements,
          measurementReadings: find_measurement_readings(survey_id, measurements),
          images: Enum.uniq_by(uploaded ++ historical, & &1.id),
          publications: attachment_links(survey["publications"], "/publication/")
        })

      {:error, :invalid_reference} ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid survey reference"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Survey not found"})
    end
  end

  defp find_survey(reference) do
    case BSON.ObjectId.decode(reference) do
      {:ok, id} ->
        case MongoDBClient.get_document_by_id("Surveys", id) do
          nil -> {:error, :not_found}
          survey -> {:ok, survey}
        end

      _ ->
        case Integer.parse(reference) do
          {numeric_id, ""} ->
            case MongoDBClient.get_all_documents("Surveys", %{"surveyId" => numeric_id}) do
              [survey | _] -> {:ok, survey}
              [] ->
                case MongoDBClient.get_all_documents("Surveys", %{"surveyId" => reference}) do
                  [survey | _] -> {:ok, survey}
                  [] -> {:error, :not_found}
                end
            end

          _ -> {:error, :invalid_reference}
        end
    end
  end

  defp find_site(site_id) when site_id in [nil, ""], do: {nil, "not_recorded"}

  defp find_site(site_id) do
    cond do
      MapSet.member?(@conflicting_site_ids, site_id) ->
        {nil, "pending_verification"}

      true ->
        case MongoDBClient.get_all_documents("Sites", %{"siteId" => site_id}) do
          [site] -> {site, "available"}
          [] -> {nil, "not_found"}
          _multiple -> {nil, "pending_verification"}
        end
    end
  end

  # Only a unique match is usable. A duplicate lookup should never silently
  # return the first geographical or biological record.
  defp unique_record(_collection, _field, id) when id in [nil, ""], do: nil

  defp unique_record(collection, field, id) do
    case MongoDBClient.get_all_documents(collection, %{field => id}) do
      [record] -> record
      _ -> nil
    end
  end

  defp find_related(nil, _source_field, _collection, _target_field), do: nil

  defp find_related(record, source_field, collection, target_field) do
    unique_record(collection, target_field, record[source_field])
  end

  defp geographic_context(nil, _location), do: nil

  defp geographic_context(site, location) do
    municipality_id = first_present([site["municipalityId"], value(location, "municipalityId")])
    municipality = unique_record("Municipalities", "municipalId", municipality_id)
    district_id = first_present([value(municipality, "districtId"), value(location, "districtId")])
    district = unique_record("Districts", "districtId", district_id)
    region_id = first_present([site["regionId"], value(location, "regionId"), value(district, "regionId")])
    region = unique_record("Regions", "regionId", region_id)
    country_id = first_present([site["countryId"], value(location, "countryId"), value(region, "countryId")])
    country = unique_record("Countries", "countryId", country_id)

    %{
      municipality: value(municipality, "municipality"),
      district: value(district, "district"),
      region: value(region, "region"),
      country: value(country, "country")
    }
  end

  defp value(nil, _field), do: nil
  defp value(record, field), do: record[field]

  defp first_present(values) do
    Enum.find(values, fn
      text when is_binary(text) -> String.trim(text) != ""
      _ -> false
    end)
  end

  defp selected_fields(nil, _fields), do: nil
  defp selected_fields(record, fields), do: Map.take(record, fields)

  defp find_control_agents(nil), do: []

  defp find_control_agents(survey_id) do
    links = MongoDBClient.get_all_documents("SurveyControlAgents", %{"surveyId" => survey_id})
    ids = linked_ids(links, "controlAgentId")

    fetch_by_ids("ControlAgents", "controlAgentId", ids)
    |> Enum.map(&Map.take(&1, ~w(controlAgentId controlAgent)))
    |> Enum.sort_by(&(&1["controlAgent"] || ""))
  end

  defp find_weed_agent_links(nil), do: []

  defp find_weed_agent_links(survey_id) do
    links = MongoDBClient.get_all_documents("SurveyWeedAgent", %{"surveyId" => survey_id})

    weeds =
      fetch_by_ids("WeedNames", "weedId", linked_ids(links, "weedId"))
      |> Map.new(fn weed ->
        # Workbook header 'Weedname' normalises to weedname, not weedName.
        {weed["weedId"], weed["weedname"] || weed["weedName"]}
      end)

    agents =
      fetch_by_ids("ControlAgents", "controlAgentId", linked_ids(links, "controlAgentId"))
      |> Map.new(fn agent -> {agent["controlAgentId"], agent["controlAgent"]} end)

    links
    |> Enum.sort_by(&(&1["swaid"] || 0))
    |> Enum.map(fn link ->
      %{
        weedId: link["weedId"],
        weedName: weeds[link["weedId"]],
        controlAgentId: link["controlAgentId"],
        controlAgent: agents[link["controlAgentId"]]
      }
    end)
  end

  defp linked_ids(records, field) do
    records
    |> Enum.map(& &1[field])
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp fetch_by_ids(_collection, _field, []), do: []

  defp fetch_by_ids(collection, field, ids) do
    MongoDBClient.get_all_documents(collection, %{field => %{"$in" => ids}})
  end

  defp find_measurements(nil), do: []

  defp find_measurements(survey_id) do
    MongoDBClient.get_all_documents("WHMeasurements", %{"surveyId" => survey_id})
    |> Enum.sort_by(&(&1["whmid"] || 0))
    |> Enum.map(&Map.take(&1, ~w(
      whmid year locality comments averageLongestPetiole averageLeafToPetiole
      averageMaxRoot averageNumberOfRamets averageNumberOfFlowers
      averageNumberOfLeaves nEichorniae nBruchi larvae pupae pathogen
      biomassAbove biomassBelow biomassDeadMaterial
    )))
  end

  defp find_measurement_readings(_survey_id, []), do: []
  defp find_measurement_readings(nil, _measurements), do: []

  defp find_measurement_readings(survey_id, measurements) do
    ids = Enum.map(measurements, & &1["whmid"]) |> Enum.reject(&is_nil/1)

    if ids == [] do
      []
    else
      MongoDBClient.get_all_documents("WHMeasurementsReadings", %{
        "surveyId" => survey_id,
        "whmid" => %{"$in" => ids}
      })
      |> Enum.sort_by(&{&1["whmid"] || 0, &1["plantNumber"] || 0})
      |> Enum.map(fn reading ->
        %{
          whmid: reading["whmid"],
          plantNumber: reading["plantNumber"],
          longestPetiole: reading["longestPetiole1"] || reading["longestPetiole"],
          leafToPetiole: reading["leaf2Petiole1"] || reading["leafToPetiole1"] || reading["leafToPetiole"],
          maxRoot: reading["maxRoot1"] || reading["maxRoot"],
          ramets: reading["numberOfRamets1"] || reading["numberOfRamets"],
          flowers: reading["numberOfFlowers1"] || reading["numberOfFlowers"],
          leaves: reading["numberOfLeaves1"] || reading["numberOfLeaves"]
        }
      end)
    end
  end

  defp historical_gridfs_images(nil), do: []

  defp historical_gridfs_images(survey_id) do
    MongoDBClient.get_all_documents("SurveyImages", %{"surveyId" => survey_id})
    |> Enum.map(& &1["gridfsId"])
    |> attachment_links("/image/")
  end

  defp attachment_links(files, prefix) when is_list(files) do
    files
    |> Enum.flat_map(fn
      %BSON.ObjectId{} = id ->
        id_string = BSON.ObjectId.encode!(id)
        [%{id: id_string, url: prefix <> id_string}]

      id when is_binary(id) ->
        case BSON.ObjectId.decode(id) do
          {:ok, _} -> [%{id: id, url: prefix <> id}]
          _ -> []
        end

      _ -> []
    end)
  end

  defp attachment_links(_, _), do: []

  defp coordinates_display(%{"geospatialCoordinates" => %{"coordinates" => [lon, lat]}})
       when is_number(lon) and is_number(lat) do
    "#{lat}, #{lon}"
  end

  defp coordinates_display(%{"geospatialCoordinates" => coordinates}) when is_binary(coordinates),
    do: coordinates

  defp coordinates_display(_), do: nil
end
