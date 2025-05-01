module Homepage exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)



-- Model


type alias Model =
    ()



-- Init


init : Model
init =
    ()



-- Update


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- View


view : Model -> Html Msg
view model =
    main_ [ class "container mx-auto flex-grow" ]
        [ section [ id "hero", class "hero-section" ]
            [ h1 [ class "hero-title" ] [ text "Center for Biological Control" ]
            , p [ class "hero-subtitle" ] [ text "Enhancing access to biological control data for research and collaboration." ]
            , div [ class "hero-image", style "background-image" "url(images/Mass_rearings.png)" ] []
            ]
        , section [ id "features", class "grid md:grid-cols-3" ]
            [ div [ class "feature-box" ]
                [ h2 [ class "feature-title" ] [ text "Weekly Publications" ]
                , p [ class "feature-text" ] [ text "Stay updated with the latest news and research from the CBC." ]
                , span [ class "feature-link" ] [ text "Get More Info" ]
                ]
            , div [ class "feature-box" ]
                [ h2 [ class "feature-title" ] [ text "Publish Findings" ]
                , p [ class "feature-text" ] [ text "Share your research with the biodiversity community." ]
                , a [ href "/publish", class "feature-link" ] [ text "Start Publishing" ]
                ]
            , div [ class "feature-box" ]
                [ h2 [ class "feature-title" ] [ text "CBC Public Calendar of Events" ]
                , p [ class "feature-text" ] [ text "Stay up to date about all the exciting events of the CBC." ]
                , a [ href "api/calendar", class "feature-link" ] [ text "View Calendar" ]
                ]
            ]
        , section [ id "cta", class "cta-section" ]
            [ h2 [ class "cta-title" ] [ text "Learn More About CBC" ]
            , p [ class "cta-text" ]
                [ text "The Center for Biological Control (CBC) is dedicated to advancing research and solutions in biological control. Visit the official CBC website to explore their research, initiatives, and the wealth of knowledge they share with the community." ]
            , a [ href "api/rhodes", class "cta-link" ] [ text "Visit CBC Website" ]
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
