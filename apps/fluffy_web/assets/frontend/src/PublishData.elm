module PublishData exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)


-- MODEL


type alias Model =
    {}


init : Model
init =
    {}


-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


-- VIEW


view : Model -> Html Msg
view _ =
    main_ [ class "resources-page animate-fade-in" ]
        [ viewHero
        , viewResources
        , viewResearchSection
        ]


viewHero : Html Msg
viewHero =
    section [ class "resources-hero" ]
        [ div [ class "resources-hero-overlay" ]
            [ div [ class "resources-hero-content" ]
                [ h1 [] [ text "Resources" ]
                , p []
                    [ text "Access CBC research material, publications and data resources "
                    , text "to support biological control research and collaboration."
                    ]
                , div [ class "resources-title-line" ] []
                , p [ class "resources-hero-secondary" ]
                    [ text "Reports, articles, scientific papers and tools to help advance knowledge and share findings." ]
                ]
            ]
        ]


viewResources : Html Msg
viewResources =
    section [ class "resources-grid animate-fade-in" ]
        [ resourceCard
            "reports"
            "bi-file-earmark-bar-graph"
            "Reports"
            "View CBC and partner reports, project summaries and research outcomes."
            "View Reports"
            "#"

        , resourceCard
            "articles"
            "bi-newspaper"
            "Popular Articles"
            "Explore accessible articles and news on biological control and related research."
            "Read Articles"
            "#"

        , resourceCard
            "papers"
            "bi-journal-text"
            "Papers"
            "Access scientific papers, publications and conference material."
            "View Papers"
            "#"

        , resourceCard
            "publish"
            "bi-cloud-arrow-up"
            "Publish Data"
            "Submit your survey data to the CBC portal using our online form or CSV upload."
            "Go to Upload Page"
            "/uploadpage"
        ]


resourceCard :
    String
    -> String
    -> String
    -> String
    -> String
    -> String
    -> Html Msg

resourceCard cardType iconClass titleText description buttonText destination =
    article [ class ("resource-card resource-card-" ++ cardType) ]
        [ div [ class "resource-card-body" ]
            [ div [ class ("resource-icon resource-icon-" ++ cardType) ]
                [ i [ class ("bi " ++ iconClass) ] [] ]

            , h2 [] [ text titleText ]

            , p []
                [ text description ]

            , a
                [ href destination
                , class ("resource-action resource-action-" ++ cardType)
                ]
                [ span [] [ text buttonText ]
                , span [ class "resource-arrow" ] [ text "→" ]
                ]
            ]
        ]


viewResearchSection : Html Msg
viewResearchSection =
    section [ class "research-feature" ]
        [ div
            [ class "research-feature-image"
            , style "background-image" "url('/images/Mass_rearings.png')"
            ]
            []

        , div [ class "research-feature-content" ]
            [ h2 [] [ text "Biological Control Research" ]

            , p []
                [ text "Our research facilities include state-of-the-art greenhouses equipped for biological control experiments. "
                , text "These controlled environments allow researchers to study plant-pest-predator interactions in detail."
                ]

            , div [ class "research-title-line" ] []

            , a
                [ href "api/rhodes"
                , class "research-learn-more animate-fade-in"
                ]
                [ text "Learn More About CBC"
                , span [] [ text " →" ]
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