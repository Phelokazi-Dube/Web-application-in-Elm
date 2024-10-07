module Homepage exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Browser.Navigation exposing (load)
import Html.Attributes exposing (attribute)
import Html.Events exposing (onClick)


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


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


-- View
view : Model -> Html Msg
view model =
    div []
        [ node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styles.css"
            ]
            []
        , div [ class "min-h-36 bg-base-50" ]
            [ header [ class "bg-neutral-100 shadow-sm", style "background-color" "rgb(17, 71, 104)"]
                [ nav [ class "container mx-auto px-4 py-3 flex items-center justify-between" ]
                    [ div [ class "brand-container" ]
                        [ img [ src "images/images.png", alt "Logo", class "logo" ] []
                        , div [ class "brand-title"] [ text "CBC" ]
                        ]
                    , ul [ class "nav-items" ]
                        [ li []  -- HOME link
                            [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                        , li [ class "group" ]  -- Dropdown for DATA
                            [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                            , ul [ class "dropdown" ]
                                [ li []
                                    [ a [ href "/downloading", class "dropdown-link" ] [ text "Get Data" ] ]
                                , li []
                                    [ a [ href "/publish", class "dropdown-link" ] [ text "Publish Data" ] ]
                                ]
                            ]
                        , li [ class "group" ]  -- Dropdown for SURVEYS
                            [ a [ href "#", class "nav-link" ] [ text "SURVEYS" ]
                            , ul [ class "dropdown" ]
                                [ li []
                                    [ a [ href "/map", class "dropdown-link" ] [ text "Map" ] ]
                                , li []
                                    [ a [ href "/survey", class "dropdown-link" ] [ text "Survey Collection" ] ]
                                ]
                            ]
                        , li []  -- CONTACT link
                            [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                        ]
                    ]
                ]
            ]
        , main_ [ class "container mx-auto" ]
            [ section [ id "hero", class "hero-section" ]
                [ h1 [ class "hero-title" ] [ text "Center for Biological Control" ]
                , p [ class "hero-subtitle" ] [ text "Enhancing access to biological control data for research and collaboration." ]
                , div [ class "hero-image", style "background-image" "url(images/Mass_rearings.png)" ] []
                ]
            , section [ id "features", class "grid grid-cols-1 md:grid-cols-3 gap-8 mb-12" ]
                [ div [ class "feature-box" ]
                    [ h2 [ class "feature-title" ] [ text "Weekly Publications" ]
                    , p [ class "feature-text" ] [ text "Stay updated with the latest news and research from the CBC." ]
                    , span [ class "feature-link" ] [ text "Get More Info" ]
                    ]
                , div [ class "feature-box" ]
                    [ h2 [ class "feature-title" ] [ text "Publish Findings" ]
                    , p [ class "feature-text" ] [ text "Share your research with the biodiversity community." ]
                    , span [ class "feature-link" ] [ text "Start Publishing" ]
                    ]
                , div [ class "feature-box" ]
                    [ h2 [ class "feature-title" ] [ text "CBC Public Calendar of Events" ]
                    , p [ class "feature-text" ] [ text "Stay informed about CBC's upcoming events." ]
                    , span [ class "feature-link" ] [ text "View Calendar" ]
                    ]
                ]
            , section [ id "cta", class "cta-section" ]
                [ h2 [ class "cta-title" ] [ text "Learn More About CBC" ]
                , p [ class "cta-text" ]
                    [ text "The Center for Biological Control (CBC) is dedicated to advancing research and solutions in biological control. Visit the official CBC website to explore their research, initiatives, and the wealth of knowledge they share with the community." ]
                , a [ href "api/rhodes", class "cta-link" ] [ text "Visit CBC Website" ]
                ]
            ]
        , footer [ class "footer" ]
            [ div [ class "container mx-auto px-4" ]
                [ div [ class "footer-content" ]
                    [ div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "CBC" ]
                        , p [ class "footer-text" ] [ text "Enhancing access to biological control data" ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Quick Links" ]
                        , ul []
                            [ li [] [ a [ href "#", class "footer-link" ] [ text "Privacy Policy" ] ]
                            , li [] [ a [ href "#", class "footer-link" ] [ text "Terms of Service" ] ]
                            , li [] [ a [ href "#", class "footer-link" ] [ text "Contact Us" ] ]
                            ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Connect With Us" ]
                        , div [ class "social-icons" ]
                            [ a [ href "#", class "social-icon" ] []
                            , a [ href "#", class "social-icon" ] []
                            , a [ href "#", class "social-icon" ] []
                            ]
                        ]
                    ]
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
