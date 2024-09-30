module PublishData exposing (..)

import Browser exposing (..)
import Html exposing (Html, div, nav, ul, li, a, input, button, text, h2, p, node, h1, br)
import Html.Attributes exposing (class, href, type_, name, placeholder)
import Html.Events exposing (onClick)
import Browser.Navigation exposing (load)
import Html.Attributes exposing (..)
import Html exposing (..)

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
        [ nav [ class "navbar" ]
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
                            [ a [ href "/survey" ] [ text "Map" ]
                            ]
                        , li []
                            [ a [ href "/surveys" ] [ text "Survey Collection" ]
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
            [ h1 [] [ text "For Users" ]
            , p []
                [ text "Welcome to the CBC Portal, please login to describe and submit your data."
                , br [] []
                , text "A CBC Data Curator will review your submission and respond ASAP. "
                , b [] [ a [ href "/", style "color" "black", style "text-decoration" "underline" ] [ text "Login" ] ]
                , text " to get started."
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