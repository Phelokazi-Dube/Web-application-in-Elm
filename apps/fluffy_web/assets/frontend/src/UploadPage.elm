module UploadPage exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)


type alias Model =
    ()


type Msg
    = NoOp



-- The view function that creates the page


view : Model -> Html Msg
view _ =
    main_ [ class "upload-page site-content-width animate-fade-in" ]
        [ section [ class "upload-page-header" ]
            [ h1 [ class "upload-page-title" ]
                [ text "Upload Your Survey Data" ]
            , p [ class "upload-page-description" ]
                [ text "Choose how you would like to add survey information to FluffyWeb." ]
            ]

        , section [ class "upload-illustration-section" ]
            [ img
                [ src "/images/upload-illustration.jpg"
                , alt "Illustration showing survey data upload"
                , class "upload-illustration"
                ]
                []
            ]

        , section [ class "upload-options-panel" ]
            [ div [ class "upload-options-intro" ]
                [ h2 []
                    [ text "Choose an upload method" ]
                , p []
                    [ text "Select the option that best matches the amount of survey data you want to add." ]
                ]

            , div [ class "upload-options-grid" ]
                [ uploadOption
                    "upload-option-form"
                    "/images/form-icon.png"
                    "Online Form"
                    "Best for entering one survey at a time using the guided data-entry form."
                    "Fill in Online Form"
                    "/uploading"

                , uploadOption
                    "upload-option-csv"
                    "/images/csv-icon.png"
                    "CSV Upload"
                    "Best for importing multiple survey records from an existing CSV file."
                    "Upload CSV File"
                    "/csvupload?collection=Surveys"
                ]
            ]
        ]


-- UPLOAD OPTION CARD
uploadOption :
    String
    -> String
    -> String
    -> String
    -> String
    -> String
    -> Html Msg
uploadOption optionClass iconPath titleText description buttonText destination =
    article [ class ("upload-option-card " ++ optionClass) ]
        [ div [ class "upload-option-icon" ]
            [ img
                [ src iconPath
                , alt (titleText ++ " icon")
                , class "upload-option-icon-image"
                ]
                []
            ]

        , h2 [ class "upload-option-title" ]
            [ text titleText ]

        , p [ class "upload-option-description" ]
            [ text description ]

        , a
            [ href destination
            , class "upload-option-action"
            ]
            [ span [] [ text buttonText ]
            , span [ class "upload-option-arrow" ]
                [ text "→" ]
            ]
        ]


-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( (), Cmd.none )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- Main entry point for the Elm app


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
