module AllSurveys exposing (..)

import Browser exposing (..)
import Browser exposing (..)
import Html exposing (Html, div, nav, ul, li, a, text, h2, node, table, thead, tbody, tr, th, td, input, button, h1, p)
import Html.Attributes exposing (class, href, attribute, type_, placeholder, attribute, name)

-- Model
type alias Model =
    {}

-- Init
init : Model
init =
    {}

-- Update
type Msg
    = NoOp

update : Msg -> Model -> Model
update msg model =
    model

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none

view : Model -> Html Msg
view model =
    div [ class "main" ]
        [ node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styling.css"
            ]
            []
        , nav [ class "navbar" ]
            [ div [ class "logo" ]
                [ h2 [] [ text "CBC" ]
                ]
            , ul []
                [ li []
                    [ a [ href "/home" ] [ text "HOME" ]
                    ]
                , li []
                    [ a [ href "/sites" ] [ text "SITES" ]
                    ]
                , li []
                    [ a [ href "#" ] [ text "DATA" ]
                    , ul []
                        [ li []
                            [ a [ href "/downloading" ] [ text "Get Data" ]
                            ]
                        , li []
                            [ a [ href "/publish" ] [ text "Publish Data" ]
                            ]
                        ]
                    ]
                , li []
                    [ a [ href "#" ] [ text "SURVEYS" ]
                    , ul []
                        [ li []
                            [ a [ href "#" ] [ text "Map" ]
                            ]
                        , li []
                            [ a [ href "#" ] [ text "Survey Collection" ]
                            ]
                        ]
                    ]
                , li []
                    [ a [ href "/contact" ] [ text "CONTACT" ]
                    ]
                ]
            , div [ class "search" ]
                [ input [ class "srch", type_ "search", name "search", placeholder "Type To text" ] []
                , button [ class "btn" ] [ text "Search" ]
                ]
            ]
        , div [ class "table-section" ]
            [ h1 [] [ text "Observations" ]
            , p [] [ text "These are all the observations collected." ]
            , table []
                [ thead []
                    [ tr []
                        [ th [] [ text "Title" ]
                        , th [] [ text "Author" ]
                        , th [] [ text "Date" ]
                        , th [] [ text "ID" ]
                        ]
                    ]
                , tbody []
                    [ tr []
                        [ td [] [ text "Sample Title 1" ]
                        , td [] [ text "Author 1" ]
                        , td [] [ text "2024-08-11" ]
                        , td [] [ text "1" ]
                        ]
                    , tr []
                        [ td [] [ text "Sample Title 2" ]
                        , td [] [ text "Author 2" ]
                        , td [] [ text "2024-08-12" ]
                        , td [] [ text "2" ]
                        ]
                    ]
                ]
            ]
        ]

main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }