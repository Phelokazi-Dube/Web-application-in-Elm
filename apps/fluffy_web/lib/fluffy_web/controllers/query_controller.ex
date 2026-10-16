defmodule FluffyWeb.QueryController do
  use FluffyWeb, :controller

  alias WaterWeeds.MongoDBClient

  def survey_details(conn, %{"survey_id" => survey_id}) do
    with {id, ""} <- Integer.parse(survey_id),
         survey when not is_nil(survey) <-
           MongoDBClient.get_all_documents("Surveys", %{"surveyId" => id})
           |> List.first() do
      site =
        case survey["siteId"] do
          nil -> nil
          "" -> nil
          site_id ->
            MongoDBClient.get_all_documents("Sites", %{"siteId" => site_id})
            |> List.first()
        end

      links =
        MongoDBClient.get_all_documents(
          "SurveyControlAgents",
          %{"surveyId" => id}
        )

      agent_ids = Enum.map(links, & &1["controlAgentId"])

      control_agents =
        if agent_ids == [] do
          []
        else
          MongoDBClient.get_all_documents(
            "ControlAgents",
            %{"controlAgentId" => %{"$in" => agent_ids}}
          )
          |> Enum.map(&Map.delete(&1, "_id"))
        end

        images =
          Enum.map(survey["photos"] || [], fn id ->
            %{
              id: id,
              url: "/image/#{id}"
            }
          end)

        publications =
          Enum.map(survey["publications"] || [], fn id ->
            %{
              id: id,
              url: "/publication/#{id}"
            }
          end)

      json(conn, %{
        survey: Map.delete(survey, "_id"),
        site: if(site, do: Map.delete(site, "_id"), else: nil),
        controlAgents: control_agents,
        images: images,
        publications: publications
      })
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid survey ID"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Survey not found"})
    end
  end
end
