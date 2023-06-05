module Homepage exposing (..)

import Browser exposing (sandbox)
import Html exposing (Html, div, nav, ul, li, a, input, button, text, h2)
import Html.Attributes exposing (class, href, type_, name, placeholder)


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


update : Msg -> Model -> Model
update msg model =
    case msg of
        NoOp ->
            model


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
                    [ a [ href "#" ] [ text "HOME" ]
                    ]
                , li []
                    [ a [ href "#" ] [ text "SITES" ]
                    ]
                , li []
                    [ a [ href "#" ] [ text "DATA" ]
                    , ul []
                        [ li []
                            [ a [ href "#" ] [ text "Get Data" ]
                            ]
                        , li []
                            [ a [ href "#" ] [ text "Publish Data" ]
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
                    [ a [ href "#" ] [ text "CONTACT" ]
                    ]
                ]
            , div [ class "search" ]
                [ input [ class "srch", type_ "search", name "", placeholder "Type To text" ] []
                , button [ class "btn" ] [ text "Search" ]
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
