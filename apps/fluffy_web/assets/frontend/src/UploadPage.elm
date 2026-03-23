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
    div [ class "flex flex-col min-h-screen bg-gray-50" ]
        [ main_ [ class "flex-grow container mx-auto px-4 py-16 text-center animate-fade-in" ]
            [ h1 [ class "text-5xl font-extrabold mb-4 text-gray-800" ]
                [ text "Upload Your Survey Data" ]
            , p [ class "text-xl mb-4 text-gray-700" ]
                [ text "You're logged in! Choose how you'd like to upload your survey information below." ]
            , div [ class "mb-8 text-gray-600 text-base space-y-2" ]
                [ p [] [ text "📑 Use the online form if you're entering just one or two surveys." ]
                , p [] [ text "📁 Use a CSV file if you're uploading many records at once." ]
                ]
            , div [ class "mb-12 flex justify-center" ]
                [ img
                    [ src "/images/upload-illustration.jpg"
                    , alt "Survey illustration"
                    , class "max-w-md w-full mx-auto"
                    ]
                    []
                ]
            , div [ class "flex justify-center gap-8 flex-wrap" ]
                [ a
                    [ href "/uploading"
                    , class "bg-blue-700 text-white px-8 py-6 rounded-xl hover:bg-blue-600 hover:scale-105 transition transform duration-200 shadow-md w-64 flex flex-col items-center space-y-2"
                    ]
                    [ img [ src "/images/form-icon.png", alt "Form icon", class "w-12 h-12" ] []
                    , span [] [ text "Fill in Online Form" ]
                    ]
                , a
                    [ href "/csvupload?collection=Surveys"
                    , class "bg-green-700 text-white px-8 py-6 rounded-xl hover:bg-green-600 hover:scale-105 transition transform duration-200 shadow-md w-64 flex flex-col items-center space-y-2"
                    ]
                    [ img [ src "/images/csv-icon.png", alt "CSV icon", class "w-12 h-12" ] []
                    , span [] [ text "Upload CSV File" ]
                    ]
                ]
            ]
        ]



update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )



init : () -> ( Model, Cmd Msg )
init _ =
    ( (), Cmd.none )

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
