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


-- Imported records use a numeric surveyId. Online submissions use only the MongoDB id


type alias Survey =
    { id : String
    , surveyId : Maybe String
    , siteId : Maybe String
    , year : Maybe String
    , assessor : Maybe String
    , percentCover : Maybe String
    , percentDamage : Maybe String
    , hyacinthMeasurements : Maybe String
    , numberStemsDamagedM2 : Maybe String
    , otherAquatics : Maybe String
    , dataCapturer : Maybe String
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


type alias AssociatedLocation =
    { location : Maybe String
    , locationId : Maybe String
    , latitude : Maybe String
    , longitude : Maybe String
    }


type alias Geography =
    { municipality : Maybe String
    , district : Maybe String
    , region : Maybe String
    , country : Maybe String
    }


type alias WeedAgentLink =
    { weedId : Maybe String
    , weedName : Maybe String
    , controlAgentId : Maybe String
    , controlAgent : Maybe String
    }


type alias Measurement =
    { whmid : Maybe String
    , year : Maybe String
    , locality : Maybe String
    , comments : Maybe String
    , averageLongestPetiole : Maybe String
    , averageLeafToPetiole : Maybe String
    , averageMaxRoot : Maybe String
    , averageNumberOfRamets : Maybe String
    , averageNumberOfFlowers : Maybe String
    , averageNumberOfLeaves : Maybe String
    , nEichorniae : Maybe String
    , nBruchi : Maybe String
    , larvae : Maybe String
    , pupae : Maybe String
    , pathogen : Maybe String
    , biomassAbove : Maybe String
    , biomassBelow : Maybe String
    }


type alias MeasurementReading =
    { whmid : Maybe String
    , plantNumber : Maybe String
    , longestPetiole : Maybe String
    , leafToPetiole : Maybe String
    , maxRoot : Maybe String
    , ramets : Maybe String
    , flowers : Maybe String
    , leaves : Maybe String
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
    , siteStatus : String
    , location : Maybe AssociatedLocation
    , geography : Maybe Geography
    , controlAgents : List ControlAgent
    , weedAgentLinks : List WeedAgentLink
    , measurements : List Measurement
    , measurementReadings : List MeasurementReading
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


-- Optional fields are decoded as Maybe, because their schemas differ.


surveyDetailsDecoder : Decode.Decoder SurveyDetails
surveyDetailsDecoder =
    Decode.succeed SurveyDetails
        |> Pipeline.required "survey" surveyDecoder
        |> Pipeline.required "site" (Decode.nullable siteDecoder)
        |> Pipeline.optional "siteStatus" Decode.string "not_found"
        |> Pipeline.optional "location" (Decode.nullable associatedLocationDecoder) Nothing
        |> Pipeline.optional "geography" (Decode.nullable geographyDecoder) Nothing
        |> Pipeline.required "controlAgents" (Decode.list controlAgentDecoder)
        |> Pipeline.optional "weedAgentLinks" (Decode.list weedAgentLinkDecoder) []
        |> Pipeline.optional "measurements" (Decode.list measurementDecoder) []
        |> Pipeline.optional "measurementReadings" (Decode.list measurementReadingDecoder) []
        |> Pipeline.required "images" (Decode.list surveyFileDecoder)
        |> Pipeline.required "publications" (Decode.list surveyFileDecoder)


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
        |> Pipeline.custom (optionalText "hyacinthMeasurements")
        |> Pipeline.custom (optionalText "numberStemsDamagedM2")
        |> Pipeline.custom (optionalText "otherAquatics")
        |> Pipeline.custom (optionalText "dataCapturer")
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


associatedLocationDecoder : Decode.Decoder AssociatedLocation
associatedLocationDecoder =
    Decode.succeed AssociatedLocation
        |> Pipeline.custom (optionalText "location")
        |> Pipeline.custom (optionalText "locationId")
        |> Pipeline.custom (optionalText "latitude")
        |> Pipeline.custom (optionalText "longitude")


geographyDecoder : Decode.Decoder Geography
geographyDecoder =
    Decode.succeed Geography
        |> Pipeline.custom (optionalText "municipality")
        |> Pipeline.custom (optionalText "district")
        |> Pipeline.custom (optionalText "region")
        |> Pipeline.custom (optionalText "country")


weedAgentLinkDecoder : Decode.Decoder WeedAgentLink
weedAgentLinkDecoder =
    Decode.succeed WeedAgentLink
        |> Pipeline.custom (optionalText "weedId")
        |> Pipeline.custom (optionalText "weedName")
        |> Pipeline.custom (optionalText "controlAgentId")
        |> Pipeline.custom (optionalText "controlAgent")


measurementDecoder : Decode.Decoder Measurement
measurementDecoder =
    Decode.succeed Measurement
        |> Pipeline.custom (optionalText "whmid")
        |> Pipeline.custom (optionalText "year")
        |> Pipeline.custom (optionalText "locality")
        |> Pipeline.custom (optionalText "comments")
        |> Pipeline.custom (optionalText "averageLongestPetiole")
        |> Pipeline.custom (optionalText "averageLeafToPetiole")
        |> Pipeline.custom (optionalText "averageMaxRoot")
        |> Pipeline.custom (optionalText "averageNumberOfRamets")
        |> Pipeline.custom (optionalText "averageNumberOfFlowers")
        |> Pipeline.custom (optionalText "averageNumberOfLeaves")
        |> Pipeline.custom (optionalText "nEichorniae")
        |> Pipeline.custom (optionalText "nBruchi")
        |> Pipeline.custom (optionalText "larvae")
        |> Pipeline.custom (optionalText "pupae")
        |> Pipeline.custom (optionalText "pathogen")
        |> Pipeline.custom (optionalText "biomassAbove")
        |> Pipeline.custom (optionalText "biomassBelow")


measurementReadingDecoder : Decode.Decoder MeasurementReading
measurementReadingDecoder =
    Decode.succeed MeasurementReading
        |> Pipeline.custom (optionalText "whmid")
        |> Pipeline.custom (optionalText "plantNumber")
        |> Pipeline.custom (optionalText "longestPetiole")
        |> Pipeline.custom (optionalText "leafToPetiole")
        |> Pipeline.custom (optionalText "maxRoot")
        |> Pipeline.custom (optionalText "ramets")
        |> Pipeline.custom (optionalText "flowers")
        |> Pipeline.custom (optionalText "leaves")


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
        , viewSite details.siteStatus details.survey.siteId details.site
        , viewAssociatedLocation details.location details.geography
        , viewControlAgents details.controlAgents
        , viewWeedAgentLinks details.weedAgentLinks
        , viewMeasurements details.measurements details.measurementReadings
        , viewPhotographs details.images
        , viewPublications details.publications
        ]


viewSurvey : Survey -> Html Msg
viewSurvey survey =
    let
        rows =
            [ detailRow "Status" (if survey.approved then "Approved" else "Pending") ]
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
                ++ optionalRow "Data captured by" survey.dataCapturer
                ++ optionalRow "Weed" survey.weed
                ++ optionalRow "Control Agent" survey.controlAgent
                ++ optionalRow "Weather" survey.weather
                ++ optionalRow "Percent Cover" survey.percentCover
                ++ optionalRow "Percent Damage" survey.percentDamage
                ++ optionalRow "Stems damaged per square metre" survey.numberStemsDamagedM2
                ++ optionalRow "Hyacinth measurements recorded" survey.hyacinthMeasurements
                ++ optionalRow "Other aquatic plants" survey.otherAquatics
                ++ optionalRow "Remarks" survey.remarks
                ++ optionalRow "Notes" survey.notes
                ++ optionalRow "Description" survey.description
                ++ optionalWeedsRow "Weeds" survey.weeds
                ++ optionalWeedsRow "Other Weeds" survey.otherWeeds
                ++ [ detailRow "Record reference" survey.id ]
    in
    div [ class "collection-grid-panel" ]
        [ h2 [ class "collection-title" ] [ text "Survey Information" ]
        , div [ class "collection-card" ]
            [ div [ class "collection-card-details" ] rows ]
        ]


viewSite : String -> Maybe String -> Maybe Site -> Html Msg
viewSite siteStatus siteId maybeSite =
    case maybeSite of
        Just site ->
            div [ class "collection-grid-panel" ]
                [ h2 [ class "collection-title" ] [ text "Site" ]
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

        Nothing ->
            let
                message =
                    case siteStatus of
                        "pending_verification" ->
                            "Site awaiting verification by CBC. The historical site identifier has conflicting records."

                        "not_recorded" ->
                            "No site was recorded for this survey."

                        _ ->
                            "Site details are not available currently."
            in
            div [ class "collection-grid-panel" ]
                [ h2 [ class "collection-title" ] [ text "Site" ]
                , div [ class "collection-card" ]
                    [ p [] [ text message ]
                    , div [ class "collection-card-details" ] (optionalRow "Site ID" siteId)
                    ]
                ]


viewAssociatedLocation : Maybe AssociatedLocation -> Maybe Geography -> Html Msg
viewAssociatedLocation maybeLocation maybeGeography =
    let
        locationRows =
            case maybeLocation of
                Nothing ->
                    []

                Just location ->
                    optionalRow "Related location" location.location
                        ++ optionalRow "Location latitude" location.latitude
                        ++ optionalRow "Location longitude" location.longitude

        geographicalRows =
            case maybeGeography of
                Nothing ->
                    []

                Just area ->
                    optionalRow "Municipality" area.municipality
                        ++ optionalRow "District" area.district
                        ++ optionalRow "Region" area.region
                        ++ optionalRow "Country" area.country

        rows =
            locationRows ++ geographicalRows
    in
    if List.isEmpty rows then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ] [ text "Geographical Context" ]
            , div [ class "collection-card" ]
                [ div [ class "collection-card-details" ] rows ]
            ]


viewWeedAgentLinks : List WeedAgentLink -> Html Msg
viewWeedAgentLinks links =
    if List.isEmpty links then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ]
                [ text ("Weed Agents (" ++ String.fromInt (List.length links) ++ ")") ]
            , div [ class "collection-grid" ] (List.map viewWeedAgentLink links)
            ]


viewWeedAgentLink : WeedAgentLink -> Html Msg
viewWeedAgentLink link =
    div [ class "collection-card" ]
        [ div [ class "collection-card-details" ]
            ([ detailRow "Weed" (Maybe.withDefault "Not recorded" link.weedName)
             , detailRow "Control Agent" (Maybe.withDefault "Not recorded" link.controlAgent)
             ]
                ++ optionalRow "Weed ID" link.weedId
                ++ optionalRow "Control Agent ID" link.controlAgentId
            )
        ]


viewMeasurements : List Measurement -> List MeasurementReading -> Html Msg
viewMeasurements measurements readings =
    if List.isEmpty measurements && List.isEmpty readings then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ] [ text "Water Hyacinth Measurements" ]
            , div [ class "collection-grid" ] (List.map viewMeasurement measurements)
            , if List.isEmpty readings then
                text ""

              else
                div [ class "survey-measurements-scroll" ]
                    [ h3 [] [ text ("Plant Readings (" ++ String.fromInt (List.length readings) ++ ")") ]
                    , table [ class "survey-measurements-table" ]
                        [ thead []
                            [ tr []
                                (List.map (\label -> th [] [ text label ])
                                    [ "Measurement ID", "Plant", "Longest petiole", "Leaf to petiole", "Max root", "Ramets", "Flowers", "Leaves" ]
                                )
                            ]
                        , tbody [] (List.map viewMeasurementReading readings)
                        ]
                    ]
            ]


viewMeasurement : Measurement -> Html Msg
viewMeasurement measurement =
    div [ class "collection-card" ]
        [ div [ class "collection-card-details" ]
            (optionalRow "Measurement ID" measurement.whmid
                ++ optionalRow "Year" measurement.year
                ++ optionalRow "Locality" measurement.locality
                ++ optionalRow "Comments" measurement.comments
                ++ optionalRow "Average longest petiole" measurement.averageLongestPetiole
                ++ optionalRow "Average leaf to petiole" measurement.averageLeafToPetiole
                ++ optionalRow "Average max root" measurement.averageMaxRoot
                ++ optionalRow "Average ramets" measurement.averageNumberOfRamets
                ++ optionalRow "Average flowers" measurement.averageNumberOfFlowers
                ++ optionalRow "Average leaves" measurement.averageNumberOfLeaves
                ++ optionalRow "Neochetina eichhorniae" measurement.nEichorniae
                ++ optionalRow "Neochetina bruchi" measurement.nBruchi
                ++ optionalRow "Larvae" measurement.larvae
                ++ optionalRow "Pupae" measurement.pupae
                ++ optionalRow "Pathogen" measurement.pathogen
                ++ optionalRow "Biomass above" measurement.biomassAbove
                ++ optionalRow "Biomass below" measurement.biomassBelow
            )
        ]


viewMeasurementReading : MeasurementReading -> Html Msg
viewMeasurementReading reading =
    tr []
        (List.map
            (\field -> td [] [ text (Maybe.withDefault "—" field) ])
            [ reading.whmid
            , reading.plantNumber
            , reading.longestPetiole
            , reading.leafToPetiole
            , reading.maxRoot
            , reading.ramets
            , reading.flowers
            , reading.leaves
            ]
        )


-- A Windows path or Drive URL is never rendered as an image.
viewPhotographs : List SurveyFile -> Html Msg
viewPhotographs images =
    if List.isEmpty images then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ]
                [ text ("Survey Photographs (" ++ String.fromInt (List.length images) ++ ")") ]
            , div [ class "collection-grid" ] (List.map viewImage images)
            ]


viewControlAgents : List ControlAgent -> Html Msg
viewControlAgents agents =
    if List.isEmpty agents then
        text ""

    else
        div [ class "collection-grid-panel" ]
            [ h2 [ class "collection-title" ]
                [ text ("Control Agents (" ++ String.fromInt (List.length agents) ++ ")") ]
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