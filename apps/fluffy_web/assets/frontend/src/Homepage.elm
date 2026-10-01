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
    main_ [ class "homepage-page animate-fade-in" ]
        [ section [ id "hero", class "hero-section" ]
            [ h1 [ class "hero-title" ] [ text "Center for Biological Control" ]
            , p [ class "hero-subtitle" ] [ text "Enhancing access to biological control data for research and collaboration." ]
            , div [ class "hero-image", style "background-image" "url(/images/Mass_rearings.png)" ] []
            ]
        , section [ id "features", class "homepage-features" ]
            [ featureCard
                "news"
                "bi-newspaper"
                "News"
                "Stay updated with the latest news and research from the CBC."
                "Get More Info"
                "/api/news"

            , featureCard
                "publish"
                "bi-cloud-arrow-up"
                "Publish Findings"
                "Contribute your research findings and survey data to the CBC."
                "Start Publishing"
                "/publish"

            , featureCard
                "calendar"
                "bi-calendar2-event"
                "CBC Public Calendar of Events"
                "Stay up to date about all the exciting events of the CBC."
                "View Calendar"
                "/api/calendar"
            ]

        , section [ id "cta", class "homepage-cbc-feature" ]
            [ div
                [ class "homepage-cbc-image"
                , style "background-image" "url('/images/Lillies.jpg')"
                ]
                []

            , div [ class "homepage-cbc-content" ]
                [ h2 [] [ text "Learn More About CBC" ]

                , p []
                    [ text "The Center for Biological Control (CBC) is dedicated to advancing research and solutions in biological control. "
                    , text "Visit the official CBC website to explore their research, initiatives, and the wealth of knowledge they share with the community."
                    ]

                , div [ class "homepage-cbc-title-line" ] []

                , a
                    [ href "/api/rhodes"
                    , class "homepage-cbc-link"
                    ]
                    [ text "Visit CBC Website"
                    , span [ class "homepage-feature-arrow" ] [ text " →" ]
                    ]
                ]
            ]
        ]


featureCard :
    String
    -> String
    -> String
    -> String
    -> String
    -> String
    -> Html Msg
featureCard cardType iconClass titleText description buttonText destination =
    article [ class ("feature-box homepage-feature-" ++ cardType) ]
        [ div [ class ("homepage-feature-icon homepage-feature-icon-" ++ cardType) ]
            [ i [ class ("bi " ++ iconClass) ] [] ]

        , h2 [ class "feature-title" ]
            [ text titleText ]

        , p [ class "feature-text" ]
            [ text description ]

        , a
            [ href destination
            , class ("feature-link homepage-feature-link homepage-feature-link-" ++ cardType)
            ]
            [ span [] [ text buttonText ]
            , span [ class "homepage-feature-arrow" ] [ text "→" ]
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
