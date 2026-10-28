module Records exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as Decode


type alias Flags =
    { baseUrl : String
    }


type alias Model =
    { isAdmin : Bool
    }


type Msg
    = AdminStatusFetched (Result Http.Error Bool)


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { isAdmin = False }
    , Http.get
        { url = flags.baseUrl ++ "/api/Mongodb/document?collection=Continents"
        , expect =
            Http.expectJson AdminStatusFetched
                (Decode.field "isAdmin" Decode.bool)
        }
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AdminStatusFetched (Ok isAdmin) ->
            ( { model | isAdmin = isAdmin }, Cmd.none )

        AdminStatusFetched (Err _) ->
            ( { model | isAdmin = False }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "records-page site-content-width animate-fade-in" ]
        [ Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css"
            ]
            []

        , div [ class "records-header" ]
            [ h1 [ class "records-title" ]
                [ text "Records" ]
            , p [ class "records-description" ]
                [ text "Browse survey records and supporting reference data used across FluffyWeb." ]
            ]

        , if model.isAdmin then
            section [ class "records-migration" ]
                [ div []
                    [ h2 [ class "records-migration-title" ]
                        [ text "CBC Data Migration" ]
                    , p [ class "records-migration-description" ]
                        [ text "Import historical records from the CBC Excel workbook." ]
                    ]
                , a
                    [ href "/admin/migration"
                    , class "records-migration-link"
                    ]
                    [ text "Open Migration" ]
                ]

          else
            text ""

        , div [ class "records-grid-panel" ]
            [ div [ class "records-grid" ]
                (referenceDataItems
                    |> List.filter (\( _, label ) -> model.isAdmin || label /= "Implementers")
                    |> List.map referenceCard
                )
            ]
        ]


-- REFERENCE DATA ITEMS


referenceDataItems : List ( String, String )
referenceDataItems =
    [ ( "fa-sun-plant-wilt", "Surveys" )
    , ( "fa-chart-column", "Survey Weed Agent" )
    , ( "fa-campground", "Sites" )
    , ( "fa-clipboard-check", "Site Inspections" )
    , ( "fa-wheat-awn-circle-exclamation", "Site Inspection Weeds" )
    , ( "fa-location-dot", "Locations" )
    , ( "fa-city", "Districts" )
    , ( "fa-solid fa-map", "Regions" )
    , ( "fa-globe", "Continents" )
    , ( "fa-flag", "Countries" )
    , ( "fa-people-group", "Implementers" )
    , ( "fa-seedling", "Programs" )
    , ( "fa-cannabis", "Weed Names" )
    , ( "fa-users", "Users" )
    , ( "fa-bugs", "Control Agents" )
    , ( "fa-pen-to-square", "Survey Control Agents" )
    , ( "fa-chart-simple", "WHM Counter" )
    , ( "fa-file-lines", "WH Measurements" )
    , ( "fa-pen-ruler", "WH Measurement Readings" )
    , ( "fa-book", "BAR" )
    ]


referenceCard : ( String, String ) -> Html msg
referenceCard ( iconClass, label ) =
    let
        isEnabled =
            label == "Surveys"
                || label == "Continents"
                || label == "Countries"
                || label == "Implementers"

        path =
            case label of
                "Surveys" ->
                    "/surveys"

                "Continents" ->
                    "/records/continents"

                "Countries" ->
                    "/records/countries"

                "Implementers" ->
                    "/records/implementers"

                _ ->
                    "#"

        cardContent =
            [ div [ class "records-card-icon" ]
                [ i [ class ("fas " ++ iconClass) ] [] ]
            , div [ class "records-card-content" ]
                [ h2 [ class "records-card-title" ]
                    [ text label ]

                , if isEnabled then
                    span [ class "records-card-status records-card-status-available" ]
                        [ text "View records" ]

                  else
                    span [ class "records-card-status records-card-status-unavailable" ]
                        [ text "Not yet available" ]
                ]
            ]
    in
    if isEnabled then
        a
            [ href path
            , class "records-card records-card-enabled"
            ]
            cardContent

    else
        div
            [ class "records-card records-card-disabled" ]
            cardContent


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }