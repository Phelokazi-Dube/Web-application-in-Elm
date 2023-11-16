module DownloadingData exposing (..)

import Browser
import Html exposing (Html, div, nav, h2, p, br, b, a, input, button, ul, li, text, node)
import Html.Attributes exposing (class, type_, name, placeholder, href, style, attribute)
import Html.Events exposing (onClick, onMouseOver)
import Browser.Navigation exposing (load)


-- Model
type alias Model =
    -- Define your model structure here
    {}


-- Init
init : Model
init =
    {}


-- Update
type Msg
    -- Define your message types here
    = NoOp


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)


subscriptions : Model -> Sub Msg
subscriptions model =
    -- Define your subscriptions here
    Sub.none


view : Model -> Html Msg
view model =
    div [ class "main" ]
        [ node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "/css/styling.css"
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
                            [ a [ href "/uploading" ] [ text "Get Data" ]
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
                            [ a [ href "#" ] [ text "Form" ]
                            ]
                        ]
                    ]
                , li []
                    [ a [ href "/contact" ] [ text "CONTACT" ]
                    ]
                ]
            , div [ class "search" ]
                [ input [ class "srch", type_ "search", name "", placeholder "Type To text" ] []
                , button [ class "btn" ] [ text "Search" ]
                ]
            ]
        , div [ class "body" ]
            [ p []
                [ text "Welcome to the CBC Portal"
                , br [] []
                , text "You can download data from "
                , b [] [ a [ href "/api/couchdb/documents/:id", style "color" "black", style "text-decoration" "underline"] [ text "here" ] ]
                ]
            ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> (init, Cmd.none)
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
