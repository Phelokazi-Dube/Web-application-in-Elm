module DownloadingData exposing (..)

import Browser
import Html exposing (Html, div, nav, h2, p, br, b, a, input, button, ul, li, text, node)
import Html.Attributes exposing (class, type_, name, placeholder, href, style, attribute, value)
import Html.Events exposing (onClick, onMouseOver, onInput)
import Browser.Navigation exposing (load)
import Http
import Json.Decode as D


-- Define a type for the document fields that we will decode
type alias Document =
    { date : Maybe String
    , site : Maybe String
    , province : Maybe String
    , notes : Maybe String
    , id : String
    }



-- Model
type alias Model =
    { searchText : String
    , results : List Document
    , status : Status
    }

type Status
    = WaitingForServer
    | ErrorHappenedOhNo
    | GettingUserInput


-- Init
init : Model
init =
    { searchText = ""
    , results = []
    , status = GettingUserInput
    }


-- Update
type Msg
    = ChangeSearchText String
    | AskServerForResults
    | ReceiveResults (Result Http.Error (List Document))

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        ChangeSearchText newText ->
            ( { model | searchText = newText }, Cmd.none )

        AskServerForResults ->
            ( { model | status = WaitingForServer }
            , fetchResults model.searchText
            )

        ReceiveResults possibleResults ->
            case possibleResults of
                Ok newResults ->
                    ( { model | results = newResults, status = GettingUserInput }, Cmd.none )

                Err _ ->
                    ( { model | status = ErrorHappenedOhNo }, Cmd.none )


-- JSON Decoder to decode a list of documents
decodeDocument : D.Decoder Document
decodeDocument =
    D.map5 Document
        (D.maybe (D.field "Date" D.string))
        (D.maybe (D.field "Site" D.string))
        (D.maybe (D.field "Province" D.string))
        (D.maybe (D.field "Notes" D.string))
        (D.field "_id" D.string)


decodeResults : D.Decoder (List Document)
decodeResults =
    D.field "documents" (D.list decodeDocument)


fetchResults : String -> Cmd Msg
fetchResults searchString =
    Http.get
        { url = "http://localhost:4000/api/couchdb/document/search?search=" ++ searchString
        , expect = Http.expectJson ReceiveResults decodeResults
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


-- View

view : Model -> Html Msg
view model =
    div [ class "main" ]
        [ nav
            [ class "navbar" ]
            [ div [ class "logo" ]
                [ h2 [] [ text "CBC" ]
                ]
            , ul []
                [ li [] [ a [ href "/home" ] [ text "HOME" ] ]
                , li [] [ a [ href "/sites" ] [ text "SITES" ] ]
                , li []
                    [ a [ href "#" ] [ text "DATA" ]
                    , ul []
                        [ li [] [ a [ href "/uploading" ] [ text "Get Data" ] ]
                        , li [] [ a [ href "/publish" ] [ text "Publish Data" ] ]
                        ]
                    ]
                , li []
                    [ a [ href "#" ] [ text "SURVEYS" ]
                    , ul []
                        [ li [] [ a [ href "/survey" ] [ text "Map" ] ]
                        , li [] [ a [ href "/surveys" ] [ text "Survey Collection" ] ]
                        ]
                    ]
                , li [] [ a [ href "/contact" ] [ text "CONTACT" ] ]
                ]
            ]
        , case model.status of
            GettingUserInput ->
                div [ class "search" ]
                    [ input
                        [ class "srch"
                        , type_ "search"
                        , placeholder "Type to search"
                        , value model.searchText
                        , onInput ChangeSearchText
                        ]
                        []
                    , button
                        [ class "btn"
                        , onClick AskServerForResults
                        ]
                        [ text "Search" ]
                    ]
            WaitingForServer ->
                div [] [ text ("Searching for '" ++ model.searchText ++ "', please wait…") ]
            ErrorHappenedOhNo ->
                div []
                    [ text <| "Oh no! An error occurred while searching for '" ++ model.searchText ++ "'."
                    , text "  Please contact the developer, who will be very sorry and will fix it ASAP."
                    ]
        , div [ class "body" ]
            (List.map viewDocument model.results)
        ]


viewDocument : Document -> Html msg
viewDocument doc =
    p [class "document-paragraph"]
        [ text "Date: "
        , text (Maybe.withDefault "No date available" doc.date)
        , br [] []
        , text "Site: "
        , text (Maybe.withDefault "No site available" doc.site)
        , br [] []
        , text "Province: "
        , text (Maybe.withDefault "No province available" doc.province)
        , br [] []
        , text "Notes: "
        , text (Maybe.withDefault "No notes available" doc.notes)
        , br [] []
        , a [ href ("api/couchdb/documents/" ++ doc.id), class "document-link"] [ text "View Document" ]
        ]

viewResults : List Document -> Html msg
viewResults results =
    div []
        (List.map viewDocument results)


-- Main

main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> (init, Cmd.none)
        , update = update
        , view = view
        , subscriptions = subscriptions
        }

