module CsvUpload exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, top)
import Url.Parser.Query as Query



-- MODEL



type alias Flags =
    { csrfToken : String
    , collection : String
    , baseUrl : String
    }


type alias Model =
    { fileName : String
    , topicId : String
    , csrfToken : String
    , collection : String
    , isSubmitting : Bool
    }


-- INIT



init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { fileName = ""
      , topicId = "some_topic_id"
      , csrfToken = flags.csrfToken
      , collection = flags.collection
      , isSubmitting = False
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = FileSelected String
    | Cancel
    | Submit


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FileSelected fileName ->
            ( { model | fileName = fileName }, Cmd.none )

        Cancel ->
            ( { model | fileName = "" }, Cmd.none )

        Submit ->
            if model.isSubmitting then
                ( model, Cmd.none )
            else
                ( { model | isSubmitting = True }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    main_
        [ class "container mx-auto flex-grow py-10 px-4 bg-slate-200 shadow-md rounded-md animate-fade-in"
        , style "max-width" "1200px"
        ]
        [ section [ id "import-data", class "import-data-section text-center" ]
            [ h1 [ class "import-data-title text-5xl text-left font-bold mb-6 text-gray-800" ] [ text "Import Data" ]
            , p [ class "import-data-description" ]
                [ text "To create a new survey, you can either import a CSV file from below or you can fill a document on this "
                , a [ href "/uploadpage", class "page-link text-blue-500 underline" ] [ text "page." ]
                ]
            , Html.form
                [ method "post"
                , action "/csvupload"
                , enctype "multipart/form-data"
                , class "column span-24 bg-white p-6 rounded-md shadow-sm"
                ]
                [ div [ class "input-group mb-4" ]
                    [ label [ class "file-label block text-left text-2xl font-medium text-gray-700 mb-4" ] [ text "CSV File" ]
                    , input
                        [ type_ "file"
                        , name "file"
                        , disabled model.isSubmitting
                        , class "file-input border-gray-300 rounded-md shadow-sm w-full"
                        , onInput FileSelected
                        ]
                        []
                    ]
                , input [ type_ "hidden", name "topic_id", value model.topicId ] []
                , input [ type_ "hidden", name "_csrf_token", value model.csrfToken ] []
                , input [ type_ "hidden", name "collection", value model.collection ] []
                , div [ class "button-group flex justify-end space-x-4 mt-4" ]
                    [ button [ type_ "submit", class "btn btn-primary text-white px-4 py-2 rounded-md hover:bg-blue-600", onClick Submit, disabled model.isSubmitting ] [ text "Upload CSV" ]
                    , button [ class "clear-btn bg-gray-300 text-gray-800 px-4 py-2 rounded-md hover:bg-gray-400", onClick Cancel, disabled model.isSubmitting ] [ text "Cancel" ]
                    ]
                ]
            ]
        ]




-- MAIN

main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }