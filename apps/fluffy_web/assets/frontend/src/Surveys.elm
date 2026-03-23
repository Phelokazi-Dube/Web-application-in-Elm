port module Surveys exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, query, string, top)
import Url.Parser.Query as Query
port downloadCsvPort : String -> Cmd msg



-- MODEL


type alias Document =
    { id : Maybe String
    , date : Maybe String
    , notes : Maybe String
    , description : Maybe String
    , site : Maybe String
    , sitename : Maybe String
    , province : Maybe String
    , approved : Bool
    }


type alias Flags =
    { csrfToken : String
    , collection : String
    , baseUrl : String
    , searchText : String
    }

type alias Model =
    { documents : List Document
    , filteredDocuments : List Document
    , searchText : String
    , error : Maybe String
    , currentPage : Int
    , itemsPerPage : Int
    , adminUser : Bool
    , baseUrl : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { documents = []
            , filteredDocuments = []
            , searchText = flags.searchText
            , error = Nothing
            , currentPage = 1
            , itemsPerPage = 12
            , adminUser = False
            , baseUrl = flags.baseUrl
            }
    in
    ( model, fetchDocuments model flags.searchText )


searchParser : Parser.Parser (Maybe String -> Maybe String) (Maybe String)
searchParser =
    Parser.s "survey" <?> Query.string "search"



-- UPDATE


type Msg
    = FetchDocuments
    | DocumentsFetched (Result Http.Error ( List Document, Bool ))
    | SearchTextChanged String
    | ClearSearch
    | NextPage
    | PrevPage
    | ApproveDocument String
    | DocumentApproved (Result Http.Error String)
    | ExportCSV



update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchDocuments ->
            let
                newUrl =
                    if String.isEmpty model.searchText then
                        "/survey"
                    else
                        "/survey?search=" ++ Url.percentEncode model.searchText
            in
            ( model
            , Cmd.batch
                [ fetchDocuments model model.searchText
                , Nav.load newUrl
                ]
            )

        ApproveDocument docId ->
            ( model, approveDocument model docId )

        DocumentApproved (Ok _) ->
            ( model, fetchDocuments model model.searchText )

        DocumentApproved (Err err) ->
            ( { model | error = Just (errorToString err) }, Cmd.none )

        DocumentsFetched (Ok ( docs, isAdmin )) ->
            ( { model
                | documents = docs
                , filteredDocuments = docs
                , error = Nothing
                , adminUser = isAdmin
              }
            , Cmd.none
            )

        DocumentsFetched (Err err) ->
            ( { model | error = Just (errorToString err) }, Cmd.none )

        SearchTextChanged text ->
            let
                lowerSearch =
                    String.toLower text

                matchesSearch doc =
                    let
                        notes =
                            String.toLower (Maybe.withDefault "" doc.notes)

                        site =
                            String.toLower (Maybe.withDefault "" doc.site)

                        province =
                            String.toLower (Maybe.withDefault "" doc.province)
                    in
                    String.contains lowerSearch notes
                        || String.contains lowerSearch site
                        || String.contains lowerSearch province

                filteredDocs =
                    if String.isEmpty text then
                        model.documents
                    else
                        List.filter matchesSearch model.documents
            in
            ( { model
                | searchText = text
                , filteredDocuments = filteredDocs
                , currentPage = 1
            }
            , Cmd.none
            )

        ClearSearch ->
            ( { model | searchText = "", filteredDocuments = model.documents }
            , Nav.load "/survey"
            )

        NextPage ->
            let
                totalPages =
                    (List.length model.filteredDocuments + model.itemsPerPage - 1) // model.itemsPerPage
            in
            ( { model | currentPage = Basics.min (model.currentPage + 1) totalPages }, Cmd.none )

        PrevPage ->
            ( { model | currentPage = Basics.max (model.currentPage - 1) 1 }, Cmd.none )
        
        ExportCSV ->
            ( model
            , downloadCsvPort
                (model.baseUrl ++ "/api/Mongodb/document/search/export"
                    ++ if model.searchText /= "" then
                           "?search=" ++ Url.percentEncode model.searchText
                       else
                           ""
                )
            )


orElse : Maybe a -> Maybe a -> Maybe a
orElse fallback primary =
    case primary of
        Just val ->
            Just val

        Nothing ->
            fallback



-- VIEW


viewContent : Model -> Html Msg
viewContent model =
    let
        start =
            (model.currentPage - 1) * model.itemsPerPage

        paginatedDocuments =
            List.drop start model.filteredDocuments
                |> List.take model.itemsPerPage
    in
    div [ class "flex flex-col min-h-screen animate-fade-in" ]
        [ h1 [ class "survey-title font-bold mx-auto text-5xl text-left mb-6" ] [ text "Survey Collections" ]
        , div [ class "search-bar container mx-auto flex items-center mb-4 px-4 py-2 border border-neutral-300 rounded-md shadow-sm" ]
            [ input
                [ class "search-input flex-grow px-2 py-1 border rounded-md"
                , type_ "text"
                , placeholder "Search by text"
                , value model.searchText
                , onInput SearchTextChanged
                ]
                []
            , div [ class "this flex space-x-2 ml-auto" ]
                [ button [ class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick FetchDocuments ] [ text "Search" ]
                , button [ class "clear-btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick ClearSearch ] [ text "X" ]
                , button [ class "btn bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-500", onClick ExportCSV ] [ text "Export CSV" ]
                ]
            ]
        , div [ class "container mx-auto px-4 py-8 shadow-lg rounded-md bg-slate-200 animate-fade-in" ]
            [ div [ class "grid document-card grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" ]
                (List.map (documentCard model.adminUser) paginatedDocuments)
            , div [ class "pagination mt-4 flex justify-between" ]
                [ button [ onClick PrevPage, disabled (model.currentPage == 1), class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700" ] [ text "Previous" ]
                , span [ class "px-4 py-2 text-gray-700" ] [ text ("Page " ++ String.fromInt model.currentPage) ]
                , button [ onClick NextPage, disabled ((model.currentPage * model.itemsPerPage) >= List.length model.filteredDocuments), class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700" ] [ text "Next" ]
                ]
            ]
        , case model.error of
            Just errorMsg ->
                div [ class "error-msg text-red-500 mt-4" ] [ text ("Error: " ++ errorMsg) ]

            Nothing ->
                text ""
        ]

view : Model -> Html Msg
view model =
    viewContent model



-- RENDER DOCUMENT CARD


documentCard : Bool -> Document -> Html Msg
documentCard isAdmin doc =
    div [ class "border rounded shadow p-4 bg-white flex-grow animate-fade-in" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h2 [ class "text-lg font-semibold" ] [ text ("Collection ID: #" ++ Maybe.withDefault "Unknown" doc.id) ]
            , if doc.approved then
                span [ class "badge active" ] [ text "Active" ]

              else
                text ""
            ]
        , div [ class "mb-2" ]
            [ text ("Created: " ++ Maybe.withDefault "No Date" doc.date) ]
        , div [ class "mb-2" ]
            [ text ("Location: " ++ Maybe.withDefault "No Site" (orElse doc.sitename doc.site)) ]
        , div [ class "mb-2" ]
            [ text ("Province: " ++ Maybe.withDefault "No Province" doc.province) ]
        , div [ class "mb-4" ]
            [ text ("Notes: " ++ Maybe.withDefault "No Notes" (orElse doc.description doc.notes)) ]
        , a [ href ("documents/" ++ Maybe.withDefault "Unknown" doc.id ++ "?collection=Surveys"), class "btn btn-primary" ] [ text "View Document" ]
        , case ( doc.id, doc.approved, isAdmin ) of
            ( Just id, False, True ) ->
                -- Only show the button if approved is False
                button [ onClick (ApproveDocument id), class "btn btn-success" ] [ text "Approve" ]

            ( Just id, False, False ) ->
                span [ class "mb-2 text-red" ]
                    [ text " NOT YET APPROVED" ]

            _ ->
                text ""

        -- Do not render the button if the document is already approved
        ]



-- Approved documents


approveDocument : Model -> String -> Cmd Msg
approveDocument model docId =
    Http.post
        { url = model.baseUrl ++ "/api/Mongodb/approve_document/" ++ docId
        , body = Http.emptyBody
        , expect = Http.expectString (always (DocumentApproved (Ok docId)))
        }



-- HTTP REQUESTS


fetchDocuments : Model -> String -> Cmd Msg
fetchDocuments model searchString =
    let
        url =
            if String.isEmpty searchString then
                model.baseUrl ++ "/api/Mongodb/document?collection=Surveys"
                -- Fetch all documents initially

            else
                model.baseUrl ++ "/api/Mongodb/document/search?search=" ++ searchString

        -- Fetch documents based on search
    in
    Http.get
        { url = url
        , expect =
            Http.expectJson DocumentsFetched
                (Decode.map2 (\a b -> ( a, b ))
                    (Decode.field "documents" (Decode.list documentDecoder))
                    (Decode.field "isAdmin" Decode.bool)
                )
        }


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.map8 Document
        (Decode.maybe (Decode.field "_id" Decode.string))
        (Decode.maybe (Decode.field "date" Decode.string))
        (Decode.maybe (Decode.field "notes" Decode.string))
        (Decode.maybe (Decode.field "description" Decode.string))
        (Decode.maybe (Decode.field "site" Decode.string))
        (Decode.maybe (Decode.field "sitename" Decode.string))
        (Decode.maybe (Decode.field "province" Decode.string))
        (Decode.maybe (Decode.field "approved" Decode.bool) |> Decode.map (Maybe.withDefault False))



-- New field added for approval status


errorToString : Http.Error -> String
errorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad body: " ++ body



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
