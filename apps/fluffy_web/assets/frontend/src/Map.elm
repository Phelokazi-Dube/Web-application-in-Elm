module Map exposing (..)

import Browser
import Html exposing (Html, div, form, input, label, button, text)
import Html.Attributes exposing (class, method, enctype, type_, value, name, action)
import Html.Events exposing (onInput, onClick)
import Contact exposing (Msg(..))

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
    form
        [ method "post"
        , action "/api/upload_csv"
        , enctype "multipart/form-data"
        , class "column span-24" -- Class for form styling
        ]
        [ div [ class "input-group" ] -- Styling for input group
            [ label [ class "file-label" ] [ text "CSV File" ]
            , input
                [ type_ "file"
                , name "file"
                , class "file-input" -- Styling for file input
                , onInput FileSelected -- Capture file input as a string (the file name)
                ] []
            ]
        , input [ type_ "hidden", name "topic_id", value model.topicId ] []
        , input [ type_ "hidden", name "csrf_token", value model.csrfToken ] []
        , div [ class "button-group" ] -- Group the buttons together
            [ button [ type_ "submit", class "submit-btn" ] [ text "Upload CSV" ]
            , button [ class "clear-btn", onClick Cancel ] [ text "Cancel" ]
            ]
        ]

-- MAIN

main =
    Browser.sandbox { init = init "token", update = update, view = view }
