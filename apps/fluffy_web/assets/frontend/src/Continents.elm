port module Continents exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, href)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline exposing (optional, required)
import Html.Events exposing (onClick)


port downloadCsvPort : String -> Cmd msg


-- FLAGS


type alias Flags =
    { baseUrl : String
    , csrfToken : String
    , collection : String
    }



-- MODEL


type alias Document =
    { id : String
    , continent : String
    , continentId : String
    , dataAccessId : String
    , dataSourceId : String
    , dataStatusId : String
    , userLogin : Maybe String
    }


type alias Model =
    { documents : List Document
    , isAdmin : Bool
    , error : Maybe String
    , baseUrl : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { documents = []
            , isAdmin = False
            , error = Nothing
            , baseUrl = flags.baseUrl
            }
    in
    ( model, fetchDocuments model )



-- MESSAGES


type Msg
    = GotDocuments (Result Http.Error Response)
    | ExportCSV



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDocuments (Ok response) ->
            ( { model | documents = response.documents, isAdmin = response.isAdmin }, Cmd.none )

        GotDocuments (Err err) ->
            ( { model | error = Just (httpErrorToString err) }, Cmd.none )

        ExportCSV ->
            ( model
            , downloadCsvPort
                (model.baseUrl
                    ++ "/api/Mongodb/document/search/export?collection=Continents"
                )
            )



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "collection-page site-content-width animate-fade-in" ]
        [ div [ class "collection-header" ]
            [ div []
                [ h1 [ class "collection-title" ]
                    [ text "Continents Collection" ]
                , p [ class "collection-description" ]
                    [ text "Browse and manage continent reference data." ]
                ]
            , div [ class "collection-header-actions" ]
                [ button
                    [ class "collection-export-button"
                    , onClick ExportCSV
                    ]
                    [ text "Export CSV" ]
                , a
                    [ href "/csvupload?collection=Continents"
                    , class "collection-import-button"
                    ]
                    [ text "Import using CSV" ]
                ]
            ]
        , case model.error of
            Just errMsg ->
                div [ class "collection-error" ]
                    [ text errMsg ]

            Nothing ->
                div [ class "collection-grid-panel" ]
                    [ div [ class "collection-grid" ]
                        (List.map viewDocument model.documents)
                    ]
        ]


viewDocument : Document -> Html msg
viewDocument doc =
    div [ class "collection-card" ]
        [ h2 [ class "collection-card-title" ]
            [ text doc.continent ]
        , div [ class "collection-card-details" ]
            [ p []
                [ span [ class "collection-field-label" ]
                    [ text "Continent ID" ]
                , text doc.continentId
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Data Access ID" ]
                , text doc.dataAccessId
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Data Source ID" ]
                , text doc.dataSourceId
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Data Status ID" ]
                , text doc.dataStatusId
                ]
            , case doc.userLogin of
                Just userLogin ->
                    p []
                        [ span [ class "collection-field-label" ]
                            [ text "Submitted by" ]
                        , text userLogin
                        ]

                Nothing ->
                    text ""
            ]
        , a
            [ href
                ("/documents/"
                    ++ doc.id
                    ++ "?collection=Continents"
                )
            , class "collection-view-button"
            ]
            [ text "View Document" ]
        ]


-- HTTP


fetchDocuments : Model -> Cmd Msg
fetchDocuments model =
    Http.get
        { url = model.baseUrl ++ "/api/Mongodb/document?collection=Continents"
        , expect = Http.expectJson GotDocuments responseDecoder
        }


type alias Response =
    { isAdmin : Bool
    , documents : List Document
    }


responseDecoder : Decode.Decoder Response
responseDecoder =
    Decode.succeed Response
        |> required "isAdmin" Decode.bool
        |> required "documents" (Decode.list documentDecoder)

stringOrNumber : Decode.Decoder String
stringOrNumber =
    Decode.oneOf
        [ Decode.string
        , Decode.int |> Decode.map String.fromInt
        , Decode.float |> Decode.map String.fromFloat
        ]

documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.succeed Document
        |> required "_id" Decode.string
        |> required "continent" Decode.string
        |> required "continentId" Decode.string
        |> required "dataAccessId" stringOrNumber
        |> required "dataSourceId" stringOrNumber
        |> required "dataStatusId" stringOrNumber
        |> optional "userLogin" (Decode.map Just Decode.string) Nothing



-- ERROR HANDLING


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad response: " ++ String.fromInt status

        Http.BadBody body ->
            "Decoding error: " ++ body



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }
