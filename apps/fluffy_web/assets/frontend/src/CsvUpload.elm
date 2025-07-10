module CsvUpload exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, (</>), (<?>), top)
import Url.Parser.Query as Query
import Json.Decode as Decode


-- MODEL

type alias Model =
    { fileName : String
    , topicId : String
    , csrfToken : String
    , collection : String
    , navKey : Nav.Key
    , currentUrl : Url
    }


-- URL Parsing for 'collection' query parameter

collectionParser : Parser (Maybe String -> a) a
collectionParser =
    Parser.map identity (Parser.s "csvupload" <?> Query.string "collection")


-- INIT

init : Decode.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init json url navKey =
    let
        collection =
            Parser.parse collectionParser url
                |> Maybe.withDefault (Just "Surveys")
                |> Maybe.withDefault "Surveys"
    in
    ( { fileName = ""
      , topicId = "some_topic_id"
      , csrfToken =
            Decode.decodeValue
                (Decode.field "csrfToken" Decode.string)
                json
            |> Result.withDefault "CSRF Token not set. This WILL result in an error on the server side."
      , collection = collection
      , navKey = navKey
      , currentUrl = url
      }
    , Cmd.none
    )


-- UPDATE

type Msg
    = FileSelected String
    | Cancel
    | UrlChanged Url
    | NoOp

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FileSelected fileName ->
            ( { model | fileName = fileName }, Cmd.none )

        Cancel ->
            ( { model | fileName = "" }, Cmd.none )

        UrlChanged url ->
            ( { model | currentUrl = url }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


-- VIEW

view : Model -> Browser.Document Msg
view model =
    { title = "Upload CSV"
    , body =
        [ div [ class "flex flex-col min-h-screen" ]
            [ Html.node "link"
                [ attribute "rel" "stylesheet"
                , attribute "href" "styles.css"
                ]
                []
            , main_
                [ class "container mx-auto flex-grow py-10 px-4 bg-slate-200 shadow-md rounded-md"
                , style "max-width" "1200px"
                ]
                [ section [ id "import-data", class "import-data-section text-center" ]
                    [ h1 [ class "import-data-title text-5xl text-left font-bold mb-6 text-gray-800" ] [ text "Import Data" ]
                    , p [ class "import-data-description" ]
                        [ text "To create a new survey, you can either import a CSV file from below or you can fill a document on this "
                        , a [ href "/publish", class "page-link text-blue-500 underline" ] [ text "page." ]
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
                                , class "file-input border-gray-300 rounded-md shadow-sm w-full"
                                , onInput FileSelected
                                ]
                                []
                            ]
                        , input [ type_ "hidden", name "topic_id", value model.topicId ] []
                        , input [ type_ "hidden", name "_csrf_token", value model.csrfToken ] []
                        , input [ type_ "hidden", name "collection", value model.collection ] []
                        , div [ class "button-group flex justify-end space-x-4 mt-4" ]
                            [ button [ type_ "submit", class "btn btn-primary text-white px-4 py-2 rounded-md hover:bg-blue-600" ] [ text "Upload CSV" ]
                            , button [ class "clear-btn bg-gray-300 text-gray-800 px-4 py-2 rounded-md hover:bg-gray-400", onClick Cancel ] [ text "Cancel" ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }


-- MAIN

main : Program Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = \_ -> NoOp
        }