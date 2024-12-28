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
        , div [ class "min-h-36 bg-base-50" ]
            [ header [ class "bg-neutral-100 shadow-sm", style "background-color" "rgb(17, 71, 104)" ]
                [ nav [ class "container mx-auto px-4 py-3 flex items-center justify-between" ]
                    [ div [ class "brand-container" ]
                        [ img [ src "images/images.png", alt "Logo", class "logo" ] []
                        , div [ class "brand-title" ] [ text "CBC" ]
                        ]
                    , ul [ class "nav-items" ]
                        [ li []
                            -- HOME link
                            [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                        , li [ class "group" ]
                            -- Dropdown for DATA
                            [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                            , ul [ class "dropdown" ]
                                [ li []
                                    [ a [ href "/downloading", class "dropdown-link" ] [ text "Get Data" ] ]
                                , li []
                                    [ a [ href "/publish", class "dropdown-link" ] [ text "Publish Data" ] ]
                                ]
                            ]
                        , li [ class "group" ]
                            -- Dropdown for SURVEYS
                            [ a [ href "#", class "nav-link" ] [ text "SURVEYS" ]
                            , ul [ class "dropdown" ]
                                [ li []
                                    [ a [ href "/map", class "dropdown-link" ] [ text "Map" ] ]
                                , li []
                                    [ a [ href "/survey", class "dropdown-link" ] [ text "Survey Collection" ] ]
                                ]
                            ]
                        , li []
                            -- CONTACT link
                            [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                        ]
                    ]
                ]
            ]
        , main_ [ class "container mx-auto" ]
            [ section [ id "first", class "first-main" ]
                [ h1 [ class "first-title" ] [ text "For Users" ]
                , p [ class "ff-title" ] [ text "Welcome to the CBC Portal, please login to describe and submit your data." ]
                , p [ class "ff-title" ] [ text "A CBC Data Curator will review your submission and respond ASAP." ]
                , a [ href "/", class "loggin-btn" ] [ text "Login with Google" ]
                ]
            , section [ id "bg-image", class "second-main" ]
                [ h2 [ class "second-title" ] [ text "Biological Control Research" ]
                , div [ class "the-bg", style "background-image" "url(images/Mass_rearings.png)" ] []
                , p [ class "some-info" ] [ text "Our research facilities include state-of-the-art greenhouses equipped for biological control experiments. These controlled environments allow researchers to study plant-pest-predator interactions in detail." ]
                ]
            ]
        , footer [ class "footer" ]
            [ div [ class "container mx-auto" ]
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
                            , li [] [ a [ href "/contact", class "footer-link" ] [ text "Contact Us" ] ]
                            ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Connect With Us" ]
                        , div [ class "social-icons" ]
                            [ a [ href "#", class "fa fa-facebook" ] []
                            , a [ href "#", class "fa fa-twitter" ] []
                            , a [ href "#", class "fa fa-instagram" ] []
                            , a [ href "#", class "fa fa-linkedin" ] []
                            ]
                        ]
                    ]
                ]
            , div [ class "footer-credits" ]
                [ p [] [ text "© 2025 Center for Biological Control. All rights reserved." ] ]
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
