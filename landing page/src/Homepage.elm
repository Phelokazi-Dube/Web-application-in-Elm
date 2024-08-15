module Homepage exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Browser.Navigation exposing (load)
import Html.Attributes exposing (attribute)


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
    div [ class "main", style "background-image" "url(images/Mass_rearing.png)" ]
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
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> (init, Cmd.none)
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
