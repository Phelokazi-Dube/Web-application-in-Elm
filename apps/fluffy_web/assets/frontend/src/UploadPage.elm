module UploadPage exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)

-- The view function that creates the page
view : () -> Html msg
view _ =
    div [ class "flex flex-col min-h-screen" ]
        [ -- Navbar
          div [ class "min-h-36 bg-base-50" ]
            [ header [ class "bg-neutral-100 shadow-sm", Html.Attributes.style "background-color" "rgb(17, 71, 104)" ]
                [ nav [ class "container mx-auto px-4 py-3 flex items-center justify-between" ]
                    [ div [ class "brand-container" ]
                        [ img [ src "images/images.png", Html.Attributes.alt "Logo", class "logo" ] []
                        , div [ class "brand-title" ] [ text "CBC" ]
                        ]
                    , ul [ class "nav-items" ]
                        [ li [] [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                        , li [ class "group" ]
                            [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                            , ul [ class "dropdown" ]
                                [ li [] [ a [ href "/downloading", class "dropdown-link" ] [ text "Get Data" ] ]
                                , li [] [ a [ href "/publish", class "dropdown-link" ] [ text "Publish Data" ] ]
                                ]
                            ]
                        , li [ class "group" ]
                            [ a [ href "#", class "nav-link" ] [ text "SURVEYS" ]
                            , ul [ class "dropdown" ]
                                [ li [] [ a [ href "/csvupload", class "dropdown-link" ] [ text "Csv Upload" ] ]
                                , li [] [ a [ href "/survey", class "dropdown-link" ] [ text "Survey Collection" ] ]
                                ]
                            ]
                        , li [] [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                        , li []
                            -- User link
                            [ a [ href "/help", class "nav-link" ] [ text "HELP" ] ]
                        ]
                    ]
                ]
            ]
        
        -- Main Content
        , main_ [ class "flex-grow container mx-auto px-4 py-12 text-center" ]
            [ h1 [ class "text-5xl font-bold mb-4 text-gray-800" ]
                [ text "Upload Survey Data" ]
            , p [ class "text-x1 mb-8 text-gray-900" ]
                [ text "You're logged in! Choose how you'd like to upload your data:" ]
            , div [ class "flex justify-center gap-6 flex-wrap" ]
                [ a [ href "/uploading", class "bg-blue-700 text-white px-6 py-3 rounded-lg hover:bg-blue-600 transition" ]
                    [ text "Fill in Online Form" ]
                , a [ href "/csvupload", class "bg-green-700 text-white px-6 py-3 rounded-lg hover:bg-green-600 transition" ]
                    [ text "Upload CSV File" ]
              ]
            ]


        -- Footer
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

-- The update function, which handles the app's state
update : msg -> () -> ()
update _ model = model

-- The initial model (empty tuple)
init : ()
init = ()

-- Main entry point for the Elm app
main =
    Browser.sandbox { init = init, update = update, view = view }
