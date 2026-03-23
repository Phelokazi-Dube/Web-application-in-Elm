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
    div [ class "flex flex-col min-h-screen" ]
        [ Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css"
            ]
            []
        , main_
            [ class "container mx-auto flex-grow py-10 px-4 bg-slate-200 shadow-md rounded-md animate-fade-in"
            , style "max-width" "1200px"
            ]
            [ section [ class "text-center" ]
                [ h1 [ class "text-5xl text-left font-bold mb-6 text-gray-800" ]
                    [ text "Other Records" ]
                , p [ class "text-lg text-left text-gray-700 mb-10 max-w-3xl" ]
                    [ text "This is structured reference data related to survey operations and site monitoring." ]
                , div [ class "grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-10" ]
                    (List.map referenceCard referenceDataItems)
                ]
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
            label == "Continents" || label == "Countries"

        path =
            case label of
                "Continents" ->
                    "/records/profile"

                "Countries" ->
                    "/records/countries"

                _ ->
                    "/records/" ++ String.toLower label

        baseContent =
            [ i [ class ("fas " ++ iconClass ++ " text-7xl mb-5 text-emerald-600") ] []
            , div [ class "text-3xl font-semibold text-gray-800 mt-2" ] [ text label ]
            ]
    in
    if isEnabled then
        a
            [ href path
            , class "bg-white hover:bg-blue-100 transition p-10 rounded-3xl shadow-xl flex flex-col items-center justify-center text-center"
            ]
            baseContent

    else
        div
            [ class "bg-white p-10 rounded-3xl shadow-xl flex flex-col items-center justify-center text-center opacity-40 cursor-not-allowed select-none"
            ]
            baseContent

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
