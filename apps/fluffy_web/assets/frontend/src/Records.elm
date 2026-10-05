module Records exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)


type alias Model =
    ()


type Msg
    = NoOp


init : () -> ( Model, Cmd Msg )
init _ =
    ( (), Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view _ =
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

        , div [ class "records-grid-panel" ]
            [ div [ class "records-grid" ]
                (List.map referenceCard referenceDataItems)
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

        path =
            case label of
                "Surveys" ->
                    "/survey"

                "Continents" ->
                    "/records/continents"

                "Countries" ->
                    "/records/countries"

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


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
