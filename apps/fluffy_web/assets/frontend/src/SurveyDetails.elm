
module SurveyDetails exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Decode


-- FLAGS


type alias Flags =
    { baseUrl : String
    , csrfToken : String
    , collection : String
    , surveyId : String
    }


-- DATA


type alias Survey =
    { surveyId : Int
    , siteId : Maybe String
    , year : Maybe Float
    , assessor : String
    , percentCover : String
    , percentDamage : String
    , remarks : String
    }


type alias Site =
    { siteName : String
    , province : Maybe String
    , waterBody : Maybe String
    , latitude : Maybe String
    , longitude : Maybe String
    }


type alias ControlAgent =
    { controlAgentId : Int
    , controlAgent : String
    }


type alias SurveyDetails =
    { survey : Survey
    , site : Maybe Site
    , controlAgents : List ControlAgent
    , images : List SurveyFile
    , publications : List SurveyFile
    }

type alias SurveyFile =
    { id : String
    , url : String
    }


-- MODEL


type alias Model =
    { details : Maybe SurveyDetails
    , isLoading : Bool
    , error : Maybe String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { details = Nothing
      , isLoading = True
      , error = Nothing
      }
    , fetchSurvey flags.baseUrl flags.surveyId
    )


-- MESSAGES


type Msg
    = GotSurvey (Result Http.Error SurveyDetails)


-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSurvey (Ok details) ->
            ( { model
                | details = Just details
                , isLoading = False
                , error = Nothing
              }
            , Cmd.none
            )

        GotSurvey (Err err) ->
            ( { model
                | isLoading = False
                , error = Just (httpErrorToString err)
              }
            , Cmd.none
            )


-- HTTP


fetchSurvey : String -> String -> Cmd Msg
fetchSurvey baseUrl surveyId =
    Http.get
        { url = baseUrl ++ "/api/query/surveys/" ++ surveyId
        , expect = Http.expectJson GotSurvey surveyDetailsDecoder
        }


-- DECODERS


surveyDetailsDecoder : Decode.Decoder SurveyDetails
surveyDetailsDecoder =
    Decode.map5 SurveyDetails
        (Decode.field "survey" surveyDecoder)
        (Decode.field "site" (Decode.nullable siteDecoder))
        (Decode.field "controlAgents" (Decode.list controlAgentDecoder))
        (Decode.field "images" (Decode.list surveyFileDecoder))
        (Decode.field "publications" (Decode.list surveyFileDecoder))

surveyFileDecoder : Decode.Decoder SurveyFile
surveyFileDecoder =
    Decode.map2 SurveyFile
        (Decode.field "id" Decode.string)
        (Decode.field "url" Decode.string)


surveyDecoder : Decode.Decoder Survey
surveyDecoder =
    Decode.map7 Survey
        (Decode.field "surveyId" Decode.int)
        (Decode.field "siteId" (Decode.nullable Decode.string))
        (Decode.field "year" (Decode.nullable Decode.float))
        (Decode.field "assessor" (nullableString ""))
        (Decode.field "percentCover" (nullableString ""))
        (Decode.field "percentDamage" (nullableString ""))
        (Decode.field "remarks" (nullableString ""))


siteDecoder : Decode.Decoder Site
siteDecoder =
    Decode.map5 Site
        (Decode.field "siteName" Decode.string)
        (Decode.field "province" (Decode.nullable Decode.string))
        (Decode.field "waterBody" (Decode.nullable Decode.string))
        (Decode.field "latitude" (Decode.nullable Decode.string))
        (Decode.field "longitude" (Decode.nullable Decode.string))


controlAgentDecoder : Decode.Decoder ControlAgent
controlAgentDecoder =
    Decode.map2 ControlAgent
        (Decode.field "controlAgentId" Decode.int)
        (Decode.field "controlAgent" Decode.string)


nullableString : String -> Decode.Decoder String
nullableString fallback =
    Decode.oneOf
        [ Decode.string
        , Decode.null fallback
        ]


-- VIEW


view : Model -> Html Msg
view model =
    div [ class "collection-page site-content-width animate-fade-in" ]
        [ div [ class "collection-header" ]
            [ div []
                [ h1 [ class "collection-title" ]
                    [ text "Survey Details" ]
                , p [ class "collection-description" ]
                    [ text "Survey information and associated CBC records." ]
                ]
            , a
                [ href "/survey"
                , class "collection-view-button"
                ]
                [ text "Back to Surveys" ]
            ]
        , if model.isLoading then
            div [ class "collection-loading" ]
                [ text "Loading survey details..." ]

          else
            case model.error of
                Just errorMessage ->
                    div [ class "collection-error" ]
                        [ text errorMessage ]

                Nothing ->
                    case model.details of
                        Just details ->
                            viewDetails details

                        Nothing ->
                            div [ class "collection-empty" ]
                                [ text "No survey details available." ]
        ]


viewDetails : SurveyDetails -> Html Msg
viewDetails details =
    div []
        [ viewSurvey details.survey
        , viewSite details.site
        , viewControlAgents details.controlAgents
        , viewImages details.images
        , viewPublications details.publications
        ]


-- SURVEY INFORMATION


viewSurvey : Survey -> Html Msg
viewSurvey survey =
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ]
            [ text "Survey Information" ]
        , div [ class "collection-card" ]
            [ div [ class "collection-card-details" ]
                [ detailRow "Survey ID" (String.fromInt survey.surveyId)
                , detailRow "Site ID" (displayMaybe survey.siteId)
                , detailRow "Year" (displayYear survey.year)
                , detailRow "Assessor" (displayValue survey.assessor)
                , detailRow "Percent Cover" (displayValue survey.percentCover)
                , detailRow "Percent Damage" (displayValue survey.percentDamage)
                , detailRow "Remarks" (displayValue survey.remarks)
                ]
            ]
        ]


-- SITE INFORMATION


viewSite : Maybe Site -> Html Msg
viewSite maybeSite =
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ]
            [ text "Site Information" ]
        , case maybeSite of
            Just site ->
                div [ class "collection-card" ]
                    [ div [ class "collection-card-details" ]
                        [ detailRow "Site Name" site.siteName
                        , detailRow "Province" (displayMaybe site.province)
                        , detailRow "Water Body" (displayMaybe site.waterBody)
                        , detailRow "Coordinates" (displayCoordinates site)
                        ]
                    ]

            Nothing ->
                div [ class "collection-empty" ]
                    [ text "No associated site information available." ]
        ]


-- CONTROL AGENTS


viewControlAgents : List ControlAgent -> Html Msg
viewControlAgents agents =
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ]
            [ text
                ("Control Agents ("
                    ++ String.fromInt (List.length agents)
                    ++ ")"
                )
            ]
        , if List.isEmpty agents then
            div [ class "collection-empty" ]
                [ text "No control agents associated with this survey." ]

          else
            div [ class "collection-grid" ]
                (List.map viewControlAgent agents)
        ]


viewControlAgent : ControlAgent -> Html Msg
viewControlAgent agent =
    div [ class "collection-card" ]
        [ div [ class "collection-card-heading" ]
            [ h2 [ class "collection-card-title" ]
                [ text agent.controlAgent ]
            ]
        , div [ class "collection-card-details" ]
            [ detailRow
                "Control Agent ID"
                (String.fromInt agent.controlAgentId)
            ]
        ]

viewImages : List SurveyFile -> Html Msg
viewImages images =
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ]
            [ text ("Survey Images (" ++ String.fromInt (List.length images) ++ ")") ]
        , if List.isEmpty images then
            div [ class "collection-empty" ]
                [ text "No images associated with this survey." ]

          else
            div [ class "collection-grid" ]
                (List.map viewImage images)
        ]


viewImage : SurveyFile -> Html Msg
viewImage image =
    div [ class "collection-card" ]
        [ a [ href image.url, target "_blank" ]
            [ img
                [ src image.url
                , alt "Survey photograph"
                , class "survey-detail-image"
                ]
                []
            ]
        ]


viewPublications : List SurveyFile -> Html Msg
viewPublications publications =
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ]
            [ text ("Publications (" ++ String.fromInt (List.length publications) ++ ")") ]
        , if List.isEmpty publications then
            div [ class "collection-empty" ]
                [ text "No publications associated with this survey." ]

          else
            div [ class "collection-grid" ]
                (List.map viewPublication publications)
        ]


viewPublication : SurveyFile -> Html Msg
viewPublication publication =
    div [ class "collection-card" ]
        [ div [ class "collection-card-details" ]
            [ a
                [ href publication.url
                , target "_blank"
                , class "collection-view-button"
                ]
                [ text "Open Publication" ]
            ]
        ]


-- DISPLAY HELPERS


detailRow : String -> String -> Html msg
detailRow label value =
    p []
        [ span [ class "collection-field-label" ]
            [ text (label ++ ": ") ]
        , text value
        ]


displayValue : String -> String
displayValue value =
    if String.trim value == "" then
        "Not recorded"

    else
        value


displayMaybe : Maybe String -> String
displayMaybe maybeValue =
    case maybeValue of
        Just value ->
            displayValue value

        Nothing ->
            "Not recorded"


displayYear : Maybe Float -> String
displayYear maybeYear =
    case maybeYear of
        Just year ->
            String.fromInt (round year)

        Nothing ->
            "Not recorded"


displayCoordinates : Site -> String
displayCoordinates site =
    case ( site.latitude, site.longitude ) of
        ( Just latitude, Just longitude ) ->
            if String.trim latitude == "" || String.trim longitude == "" then
                "Coordinates unavailable"

            else
                latitude ++ ", " ++ longitude

        _ ->
            "Coordinates unavailable"


-- ERROR HANDLING


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Invalid URL: " ++ url

        Http.Timeout ->
            "The request timed out."

        Http.NetworkError ->
            "Network error. Please check your connection."

        Http.BadStatus status ->
            if status == 404 then
                "Survey not found."

            else
                "Unable to load survey. HTTP status: "
                    ++ String.fromInt status

        Http.BadBody body ->
            "Unable to decode survey data: " ++ body


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }