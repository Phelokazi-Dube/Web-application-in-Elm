module PublishData exposing (..)

import Browser exposing (..)
import Browser.Navigation exposing (load)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)



-- Model


type alias Model =
    -- Define your model structure here
    {}



-- Init


init : Model
init =
    {}



-- Update


type
    Msg
    -- Define your message types here
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    -- Define your subscriptions here
    Sub.none


view : Model -> Html Msg
view model =
    div [ class "flex flex-col min-h-screen" ]
        [ node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styles.css"
            ]
            []
        , main_ [ class "container mx-auto flex-grow " ]
            [ section [ id "first", class "first-main" ]
                [ h1 [ class "first-title" ] [ text "For Users" ]
                , p [ class "ff-title" ] [ text "Welcome to the CBC Portal, please login to describe and submit your data." ]
                , p [ class "ff-title" ] [ text "A CBC Data Curator will review your submission and respond ASAP." ]
                , a [ href "/uploadpage", class "loggin-btn" ] [ text "Proceed to Upload Page" ]
                ]
            , section [ id "bg-image", class "second-main" ]
                [ h2 [ class "second-title" ] [ text "Biological Control Research" ]
                , div [ class "the-bg", style "background-image" "url(images/Mass_rearings.png)" ] []
                , p [ class "some-info" ] [ text "Our research facilities include state-of-the-art greenhouses equipped for biological control experiments. These controlled environments allow researchers to study plant-pest-predator interactions in detail." ]
                ]
            ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( init, Cmd.none )
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
