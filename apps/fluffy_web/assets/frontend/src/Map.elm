module Map exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)



-- MODEL


type alias Model =
    { fileName : String
    , topicId : String
    , csrfToken : String
    }


init : String -> Model
init csrfToken =
    { fileName = ""
    , topicId = "some_topic_id"
    , csrfToken = csrfToken
    }



-- UPDATE


type Msg
    = FileSelected String
    | Cancel


update : Msg -> Model -> Model
update msg model =
    case msg of
        FileSelected fileName ->
            { model | fileName = fileName }

        Cancel ->
            { model | fileName = "" }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "flex flex-col min-h-screen" ]
        [ Html.node "link"
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
        , main_
            [ class "container mx-auto flex-grow py-10 px-4 bg-slate-200 shadow-md rounded-md"
            , style "max-width" "1200px"
            ]
            [ section [ id "import-data", class "import-data-section text-center" ]
                [ h1 [ class "import-data-title text-5xl text-left font-bold mb-6 text-gray-800" ] [ text "Import Data" ]
                , p [ class "import-data-description" ]
                    [ text "To create a new survey, you can either import a CSV file from below or you can fill a document on this "
                    , a [ href "/document", class "page-link text-blue-500 underline" ] [ text "page." ]
                    ]
                , Html.form
                    [ method "post"
                    , action "/api/Mongodb/upload_csv"
                    , enctype "multipart/form-data"
                    , class "column span-24 bg-white p-6 rounded-md shadow-sm"
                    ]
                    [ div [ class "input-group mb-4" ]
                        [ label [ class "file-label block text-left text-2xl font-medium text-gray-700 mb-4" ] [ text "CSV File" ]
                        , input
                            [ type_ "file"
                            , name "file"
                            , class "file-input border-gray-300 rounded-md shadow-sm w-full"
                            , onInput FileSelected
                            ]
                            []
                        ]
                    , input [ type_ "hidden", name "topic_id", value model.topicId ] []
                    , input [ type_ "hidden", name "csrf_token", value model.csrfToken ] []
                    , div [ class "button-group flex justify-end space-x-4 mt-4" ]
                        [ button [ type_ "submit", class "btn btn-primary text-white px-4 py-2 rounded-md hover:bg-blue-600" ] [ text "Upload CSV" ]
                        , button [ class "clear-btn bg-gray-300 text-gray-800 px-4 py-2 rounded-md hover:bg-gray-400", onClick Cancel ] [ text "Cancel" ]
                        ]
                    ]
                ]
            ]
        , footer [ class "footer mt-8" ]
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



-- MAIN


main : Program () Model Msg
main =
    Browser.sandbox { init = init "token", update = update, view = view }
