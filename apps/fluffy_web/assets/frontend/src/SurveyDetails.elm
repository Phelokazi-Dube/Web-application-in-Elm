module SurveyDetails exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline


-- FLAGS


type alias Flags =
    { baseUrl : String
    , csrfToken : String
    , collection : String
    , surveyId : String
    , backUrl : String
    }


-- Imported records use a numeric surveyId. Online submissions use only the
-- MongoDB id; both are first-class survey records.


type alias Survey =
    { id : String
    , surveyId : Maybe String
    , siteId : Maybe String
    , year : Maybe String
    , assessor : Maybe String
    , percentCover : Maybe String
    , percentDamage : Maybe String
    , remarks : Maybe String
    , surveyType : Maybe String
    , date : Maybe String
    , weed : Maybe String
    , controlAgent : Maybe String
    , weather : Maybe String
    , province : Maybe String
    , country : Maybe String
    , siteName : Maybe String
    , notes : Maybe String
    , description : Maybe String
    , coordinates : Maybe String
    , weeds : Maybe String
    , otherWeeds : Maybe String
    , approved : Bool
    }


type alias Site =
    { siteName : String
    , province : Maybe String
    , waterBody : Maybe String
    , latitude : Maybe String
    , longitude : Maybe String
    }


type alias ControlAgent =
    { controlAgentId : Maybe String
    , controlAgent : String
    }


type alias SurveyFile =
    { id : String
    , url : String
    }


type alias SurveyDetails =
    { survey : Survey
    , site : Maybe Site
    , controlAgents : List ControlAgent
    , images : List SurveyFile
    , publications : List SurveyFile
    }


type alias Model =
    { details : Maybe SurveyDetails
    , isLoading : Bool
    , error : Maybe String
    , backUrl : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { details = Nothing, isLoading = True, error = Nothing, backUrl = flags.backUrl }
    , Http.get
        { url = flags.baseUrl ++ "/api/query/surveys/" ++ flags.surveyId
        , expect = Http.expectJson GotSurvey surveyDetailsDecoder
        }
    )


type Msg
    = GotSurvey (Result Http.Error SurveyDetails)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSurvey (Ok details) ->
            ( { model | details = Just details, isLoading = False, error = Nothing }, Cmd.none )

        GotSurvey (Err err) ->
            ( { model | isLoading = False, error = Just (httpErrorToString err) }, Cmd.none )


-- The API returns the same envelope for imported and form-created surveys.
-- Optional fields are decoded as Maybe, because their schemas differ.


surveyDetailsDecoder : Decode.Decoder SurveyDetails
surveyDetailsDecoder =
    Decode.map5 SurveyDetails
        (Decode.field "survey" surveyDecoder)
        (Decode.field "site" (Decode.nullable siteDecoder))
        (Decode.field "controlAgents" (Decode.list controlAgentDecoder))
        (Decode.field "images" (Decode.list surveyFileDecoder))
        (Decode.field "publications" (Decode.list surveyFileDecoder))


textValue : Decode.Decoder String
textValue =
    Decode.oneOf
        [ Decode.string
        , Decode.int |> Decode.map String.fromInt
        , Decode.float |> Decode.map String.fromFloat
        ]


optionalText : String -> Decode.Decoder (Maybe String)
optionalText fieldName =
    Decode.oneOf
        [ Decode.field fieldName (Decode.nullable textValue)
        , Decode.succeed Nothing
        ]


surveyDecoder : Decode.Decoder Survey
surveyDecoder =
    Decode.succeed Survey
        |> Pipeline.required "id" Decode.string
        |> Pipeline.custom (optionalText "surveyId")
        |> Pipeline.custom (optionalText "siteId")
        |> Pipeline.custom (optionalText "year")
        |> Pipeline.custom (optionalText "assessor")
        |> Pipeline.custom (optionalText "percentCover")
        |> Pipeline.custom (optionalText "percentDamage")
        |> Pipeline.custom (optionalText "remarks")
        |> Pipeline.custom (optionalText "surveyType")
        |> Pipeline.custom (optionalText "date")
        |> Pipeline.custom (optionalText "weed")
        |> Pipeline.custom (optionalText "controlAgent")
        |> Pipeline.custom (optionalText "weather")
        |> Pipeline.custom (optionalText "province")
        |> Pipeline.custom (optionalText "country")
        |> Pipeline.custom
            (Decode.oneOf
                [ Decode.field "sitename" (Decode.nullable textValue)
                , Decode.field "site" (Decode.nullable textValue)
                , Decode.succeed Nothing
                ]
            )
        |> Pipeline.custom (optionalText "notes")
        |> Pipeline.custom (optionalText "description")
        |> Pipeline.custom (optionalText "coordinatesDisplay")
        |> Pipeline.custom (optionalText "weeds")
        |> Pipeline.custom (optionalText "otherWeeds")
        |> Pipeline.optional "approved" Decode.bool False


siteDecoder : Decode.Decoder Site
siteDecoder =
    Decode.succeed Site
        |> Pipeline.optional "siteName" textValue "Unknown site"
        |> Pipeline.custom (optionalText "province")
        |> Pipeline.custom (optionalText "waterBody")
        |> Pipeline.custom (optionalText "latitude")
        |> Pipeline.custom (optionalText "longitude")


controlAgentDecoder : Decode.Decoder ControlAgent
controlAgentDecoder =
    Decode.map2 ControlAgent
        (optionalText "controlAgentId")
        (Decode.oneOf [ Decode.field "controlAgent" textValue, Decode.succeed "Unnamed agent" ])


surveyFileDecoder : Decode.Decoder SurveyFile
surveyFileDecoder =
    Decode.map2 SurveyFile
        (Decode.field "id" Decode.string)
        (Decode.field "url" Decode.string)


-- VIEW


view : Model -> Html Msg
view model =
    div [ class "collection-page site-content-width animate-fade-in" ]
        [ div [ class "collection-header" ]
            [ div []
                [ h1 [ class "collection-title" ] [ text "Survey Details" ]
                , p [ class "collection-description" ]
                    [ text "Survey information and associated CBC records." ]
                ]
            , a [ href model.backUrl, class "collection-view-button" ]
                [ text "Back to Survey Data" ]
            ]
        , if model.isLoading then
            div [ class "collection-loading" ] [ text "Loading survey details..." ]

          else
            case model.error of
                Just errorMessage ->
                    div [ class "collection-error" ] [ text errorMessage ]

                Nothing ->
                    case model.details of
                        Just details ->
                            viewDetails details

                        Nothing ->
                            div [ class "collection-empty" ] [ text "No survey details available." ]
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


viewSurvey : Survey -> Html Msg
viewSurvey survey =
    let
        rows =
            [ detailRow "Document ID" survey.id
            , detailRow "Status" (if survey.approved then "Approved" else "Pending")
            ]
                ++ optionalRow "Survey ID" survey.surveyId
                ++ optionalRow "Survey Type" survey.surveyType
                ++ optionalRow "Date" survey.date
                ++ optionalRow "Year" survey.year
                ++ optionalRow "Site ID" survey.siteId
                ++ optionalRow "Site" survey.siteName
                ++ optionalRow "Province" survey.province
                ++ optionalRow "Country" survey.country
                ++ optionalRow "Coordinates (latitude, longitude)" survey.coordinates
                ++ optionalRow "Assessor" survey.assessor
                ++ optionalRow "Weed" survey.weed
                ++ optionalRow "Control Agent" survey.controlAgent
                ++ optionalRow "Weather" survey.weather
                ++ optionalRow "Percent Cover" survey.percentCover
                ++ optionalRow "Percent Damage" survey.percentDamage
                ++ optionalRow "Remarks" survey.remarks
                ++ optionalRow "Notes" survey.notes
                ++ optionalRow "Description" survey.description
                ++ optionalWeedsRow "Weeds" survey.weeds
                ++ optionalWeedsRow "Other Weeds" survey.otherWeeds
    in
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ] [ text "Survey Information" ]
        , div [ class "collection-card" ]
            [ div [ class "collection-card-details" ] rows ]
        ]


viewSite : Maybe Site -> Html Msg
viewSite maybeSite =
    case maybeSite of
        Nothing ->
            text ""

        Just site ->
            div [ class "collection-grid-panel" ]
                [ h2 [ class "collection-title" ] [ text "Associated Site" ]
                , div [ class "collection-card" ]
                    [ div [ class "collection-card-details" ]
                        ([ detailRow "Site Name" site.siteName ]
                            ++ optionalRow "Province" site.province
                            ++ optionalRow "Water Body" site.waterBody
                            ++ optionalRow "Latitude" site.latitude
                            ++ optionalRow "Longitude" site.longitude
                        )
                    ]
                ]


viewControlAgents : List ControlAgent -> Html Msg
viewControlAgents agents =
    if List.isEmpty agents then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ]
                [ text ("Linked Control Agents (" ++ String.fromInt (List.length agents) ++ ")") ]
            , div [ class "collection-grid" ] (List.map viewControlAgent agents)
            ]


viewControlAgent : ControlAgent -> Html Msg
viewControlAgent agent =
    div [ class "collection-card" ]
        [ div [ class "collection-card-heading" ]
            [ h2 [ class "collection-card-title" ] [ text agent.controlAgent ] ]
        , div [ class "collection-card-details" ]
            (optionalRow "Control Agent ID" agent.controlAgentId)
        ]


viewImages : List SurveyFile -> Html Msg
viewImages images =
    if List.isEmpty images then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ]
                [ text ("Survey Images (" ++ String.fromInt (List.length images) ++ ")") ]
            , div [ class "collection-grid" ] (List.map viewImage images)
            ]


viewImage : SurveyFile -> Html Msg
viewImage image =
    div [ class "collection-card" ]
        [ a [ href image.url, target "_blank", rel "noopener noreferrer" ]
            [ img [ src image.url, alt "Survey photograph", class "survey-detail-image" ] [] ]
        ]


viewPublications : List SurveyFile -> Html Msg
viewPublications publications =
    if List.isEmpty publications then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ]
                [ text ("Publications (" ++ String.fromInt (List.length publications) ++ ")") ]
            , div [ class "collection-grid" ] (List.map viewPublication publications)
            ]


viewPublication : SurveyFile -> Html Msg
viewPublication publication =
    div [ class "collection-card" ]
        [ a
            [ href publication.url
            , target "_blank"
            , rel "noopener noreferrer"
            , class "collection-view-button"
            ]
            [ text "Open Publication" ]
        ]


-- HELPERS


detailRow : String -> String -> Html msg
detailRow label value =
    p []
        [ span [ class "collection-field-label" ] [ text (label ++ ": ") ]
        , text value
        ]


optionalRow : String -> Maybe String -> List (Html msg)
optionalRow label maybeValue =
    case maybeValue of
        Just value ->
            if String.trim value == "" then
                []

            else
                [ detailRow label value ]

        Nothing ->
            []


optionalWeedsRow : String -> Maybe String -> List (Html msg)
optionalWeedsRow label maybeValue =
    maybeValue
        |> Maybe.andThen formatWeeds
        |> optionalRow label


formatWeeds : String -> Maybe String
formatWeeds raw =
    let
        entryDecoder =
            Decode.map3
                (\name present absent ->
                    name
                        ++ (if present then
                                " (present)"

                            else if absent then
                                " (absent)"

                            else
                                ""
                           )
                )
                (Decode.field "name" Decode.string)
                (Decode.oneOf [ Decode.field "present" Decode.bool, Decode.succeed False ])
                (Decode.oneOf [ Decode.field "absent" Decode.bool, Decode.succeed False ])
    in
    case Decode.decodeString (Decode.list entryDecoder) raw of
        Ok entries ->
            if List.isEmpty entries then
                Nothing

            else
                Just (String.join ", " entries)

        Err _ ->
            if String.trim raw == "" then
                Nothing

            else
                Just raw


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl _ ->
            "Invalid survey URL."

        Http.Timeout ->
            "The request timed out."

        Http.NetworkError ->
            "Network error. Please check your connection."

        Http.BadStatus status ->
            if status == 404 then
                "Survey not found."

            else
                "Unable to load survey. HTTP status: " ++ String.fromInt status

        Http.BadBody body ->
            "Unable to decode survey data: " ++ body


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }