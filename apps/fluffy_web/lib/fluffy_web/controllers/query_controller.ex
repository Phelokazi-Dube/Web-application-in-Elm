defmodule FluffyWeb.QueryController do
  use FluffyWeb, :controller

  alias FluffyWeb.ControllerHelpers
  alias WaterWeeds.MongoDBClient

  # A survey can be addressed by its historical numeric surveyId or by its
  # MongoDB ObjectId. Online form submissions do not require a surveyId.
  def survey_details(conn, %{"survey_id" => reference}) do
    case find_survey(reference) do
      {:ok, survey} ->
        site = find_site(survey["siteId"])
        agents = find_control_agents(survey["surveyId"])

        # Return only the survey data used by the public detail page.
        visible_fields = ~w(
          surveyId siteId year assessor percentCover percentDamage remarks
          surveyType date weed controlAgent weather province country site
          sitename notes description weeds otherWeeds approved
        )

        survey_data =
          survey
          |> Map.take(visible_fields ++ ["_id"])
          |> ControllerHelpers.normalize_mongo_id()
          |> Map.put("coordinatesDisplay", coordinates_display(survey))

        json(conn, %{
          survey: survey_data,
          site: if(site, do: Map.delete(site, "_id"), else: nil),
          controlAgents: agents,
          images: attachment_links(survey["photos"], "/image/"),
          publications: attachment_links(survey["publications"], "/publication/")
        })

      {:error, :invalid_reference} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid survey reference"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Survey not found"})
    end
  end

  defp find_survey(reference) do
    # ObjectId first, so even a 24-digit hex-only ID is unambiguous.
    case BSON.ObjectId.decode(reference) do
      {:ok, object_id} ->
        case MongoDBClient.get_document_by_id("Surveys", object_id) do
          nil -> {:error, :not_found}
          survey -> {:ok, survey}
        end

      _ ->
        case Integer.parse(reference) do
          {numeric_id, ""} ->
            # Historical CSV imports normalize surveyId to a number.
            case MongoDBClient.get_all_documents("Surveys", %{"surveyId" => numeric_id}) do
              [survey | _] -> {:ok, survey}
              [] ->
                case MongoDBClient.get_all_documents("Surveys", %{"surveyId" => reference}) do
                  [survey | _] -> {:ok, survey}
                  [] -> {:error, :not_found}
                end
            end

          _ ->
            {:error, :invalid_reference}
        end
    end
  end

  defp find_site(nil), do: nil
  defp find_site(""), do: nil

  defp find_site(site_id) do
    MongoDBClient.get_all_documents("Sites", %{"siteId" => site_id})
    |> List.first()
  end

  defp find_control_agents(nil), do: []

  defp find_control_agents(survey_id) do
    links = MongoDBClient.get_all_documents("SurveyControlAgents", %{"surveyId" => survey_id})
    ids = Enum.map(links, & &1["controlAgentId"]) |> Enum.reject(&is_nil/1)

    if ids == [] do
      []
    else
      MongoDBClient.get_all_documents("ControlAgents", %{"controlAgentId" => %{"$in" => ids}})
      |> Enum.map(&Map.delete(&1, "_id"))
    end
  end

  defp attachment_links(files, prefix) when is_list(files) do
    files
    |> Enum.filter(&(is_binary(&1) or match?(%BSON.ObjectId{}, &1)))
    |> Enum.map(fn id ->
      id_string = if is_binary(id), do: id, else: BSON.ObjectId.encode!(id)
      %{id: id_string, url: prefix <> id_string}
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
