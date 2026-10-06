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
        [ class "csv-upload-page site-content-width animate-fade-in" ]
        [ section [ class "csv-upload-header" ]
            [ h1 [ class "csv-upload-title" ]
                [ text "Import CSV Data" ]
            , p [ class "csv-upload-description" ]
                [ text "Upload a CSV file to add multiple records to "
                , span [ class "csv-upload-collection-name" ]
                    [ text model.collection ]
                , text "."
                ]
            ]

        , section [ class "csv-upload-panel" ]
            [ div [ class "csv-upload-panel-header" ]
                [ div [ class "csv-upload-icon" ]
                    [ img
                        [ src "/images/csv-icon.png"
                        , alt "CSV file icon"
                        ]
                        []
                    ]
                , div []
                    [ h2 [ class "csv-upload-panel-title" ]
                        [ text "Upload CSV File" ]
                    , p [ class "csv-upload-panel-description" ]
                        [ text "Choose a CSV file from your computer. The records will be imported into the selected collection." ]
                    ]
                ]

            , Html.form
                [ method "post"
                , action "/csvupload"
                , enctype "multipart/form-data"
                , class "csv-upload-form"
                ]
                [ div [ class "csv-upload-field" ]
                    [ label
                        [ for "csv-file"
                        , class "csv-upload-label"
                        ]
                        [ text "CSV File" ]
                    , input
                        [ id "csv-file"
                        , type_ "file"
                        , name "file"
                        , accept ".csv,text/csv"
                        , disabled model.isSubmitting
                        , class "csv-upload-file-input"
                        , onInput FileSelected
                        ]
                        []
                    ]

                , input
                    [ type_ "hidden"
                    , name "topic_id"
                    , value model.topicId
                    ]
                    []

                , input
                    [ type_ "hidden"
                    , name "_csrf_token"
                    , value model.csrfToken
                    ]
                    []

                , input
                    [ type_ "hidden"
                    , name "collection"
                    , value model.collection
                    ]
                    []

                , div [ class "csv-upload-actions" ]
                    [ a
                        [ href "/uploadpage"
                        , class "csv-upload-cancel-button"
                        ]
                        [ text "Cancel" ]

                    , button
                        [ type_ "submit"
                        , class "csv-upload-submit-button"
                        , onClick Submit
                        , disabled model.isSubmitting
                        ]
                        [ text
                            (if model.isSubmitting then
                                "Uploading..."

                             else
                                "Upload CSV"
                            )
                        ]
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
