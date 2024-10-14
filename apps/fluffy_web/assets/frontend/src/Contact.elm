module Contact exposing (..)

import Browser exposing (sandbox)
import Html exposing (Html, div, nav, ul, li, a, input, button, text, h1, h2, form, label, textarea, img, main_, section, p, footer, header, i)
import Html.Attributes exposing (class, href, type_, name, placeholder, required, method, action, attribute, value)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing (..)
import Html exposing (..)

-- Model
type alias Model =
    { name : String
    , surname : String
    , message : String
    , email : String
    }

-- Init
init : Model
init =
    { name = ""
    , surname = ""
    , message = ""
    , email = ""
    }

-- Update
type Msg
    = Cancel
    | UpdateName String
    | UpdateSurname String
    | UpdateMessage String
    | UpdateEmail String

update : Msg -> Model -> Model
update msg model =
    case msg of
        Cancel ->
            { model | name = "", surname = "", message = "", email = "" }

        UpdateName newName ->
            { model | name = newName }

        UpdateSurname newSurname ->
            { model | surname = newSurname }

        UpdateMessage newMessage ->
            { model | message = newMessage }

        UpdateEmail newEmail ->
            { model | email = newEmail }

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none

view : Model -> Html Msg
view model =
    div []
        [ Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styles.css"
            ]
            []
        , Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styles.css"
            ]
            []
        , div [ class "min-h-36 bg-base-50" ]
            [ header [ class "bg-neutral-100 shadow-sm", style "background-color" "rgb(17, 71, 104)" ]
                [ nav [ class "container mx-auto px-4 py-3 flex items-center justify-between" ]
                    [ div [ class "brand-container" ]
                        [ img [ src "images/images.png", Html.Attributes.alt "Logo", class "logo" ] []
                        , div [ class "brand-title"] [ text "CBC" ]
                        ]
                    , ul [ class "nav-items" ]
                        [ li []
                            [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                        , li [ class "group" ]
                            [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                            , ul [ class "dropdown" ]
                                [ li []
                                    [ a [ href "/downloading", class "dropdown-link" ] [ text "Get Data" ] ]
                                , li []
                                    [ a [ href "/publish", class "dropdown-link" ] [ text "Publish Data" ] ]
                                ]
                            ]
                        , li [ class "group" ]
                            [ a [ href "#", class "nav-link" ] [ text "SURVEYS" ]
                            , ul [ class "dropdown" ]
                                [ li []
                                    [ a [ href "/map", class "dropdown-link" ] [ text "Map" ] ]
                                , li []
                                    [ a [ href "/survey", class "dropdown-link" ] [ text "Survey Collection" ] ]
                                ]
                            ]
                        , li []
                            [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                        ]
                    ]
                ]
            ]
        , main_ [ class "container mx-auto" ]
            [ section [ id "contacts", class "contact-main" ]
                [ h1 [ class "contact-title" ] [ text "Contact Us" ]
                , div [ class "contact-body" ]
                    [ Html.form [ method "post", action "https://submit-form.com/f0t80tNVF" ]
                        [ div []
                            [ label [] [ text "Name: " ]
                            , input [ type_ "text", name "name", placeholder "Enter your name", required True, value model.name, onInput UpdateName ] []
                            ]
                        , div []
                            [ label [] [ text "Surname: " ]
                            , input [ type_ "text", name "surname", placeholder "Enter your surname", required True, value model.surname, onInput UpdateSurname ] []
                            ]
                        , div []
                            [ label [] [ text "Message: " ]
                            , textarea [ name "message", placeholder "Enter your message", required True, onInput UpdateMessage ] [ text model.message ]
                            ]
                        , div []
                            [ label [] [ text "Email Address: " ]
                            , input [ type_ "email", name "email", placeholder "Enter your email address", required True, value model.email, onInput UpdateEmail ] []
                            ]
                        , button [ type_ "submit" ] [ text "Send Message" ]
                        , button [ class "clear-btn", onClick Cancel ] [ text "Cancel" ]
                        ]
                    ]
                ]
            , section [ id "details", class "main-details" ]
                [ h2 [ class "details-title" ] [ text "Support Information" ]
                , p [ class "details-info" ] [ text "For any inquiries or support, please don't hesitate to reach out to us using the contact form or the information below:" ]
                , ul [ class "details-items"]
                    [ li [ class "the-email"] [ i [ class "fa fa-envelope" ] [] , text " cbcinfo@ru.ac.za" ]
                    , li [ class "numbers"] [ i [ class "fa fa-phone" ] [] , text " +27 46 603 8763" ]
                    , li [ class "location"] [ i [ class "fa fa-map-marker" ] [] , text " The Centre for Biological Control (CBC), Department of Zoology and Entomology, Life Science Building, Barrat Complex, African Street, Makhanda (Grahamstown)" ]
                    ]
                ]
                , div [ class "hours" ]
                    [ h3 [ class "the-hours" ] [ text "Office Hours" ]
                    , p [ class "hours-info" ] [ text "Monday - Friday: 8:00 AM - 4:00 PM" ]
                    , p [ class "hours-info" ] [ text "Saturday - Sunday: Closed" ]
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
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }
