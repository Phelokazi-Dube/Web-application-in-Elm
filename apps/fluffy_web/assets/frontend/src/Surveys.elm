module Surveys exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url exposing (Url)
import Url.Parser as Parser exposing (Parser, (<?>), Query, query, string, top)
import Url.Parser.Query as Query
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode



-- MODEL


type alias Document =
    { id : Maybe String
    , date : Maybe String
    , notes : Maybe String
    , site : Maybe String
    , province : Maybe String
    , approved : Bool
    }


type alias Model =
    { key : Nav.Key
    , documents : List Document
    , filteredDocuments : List Document
    , searchText : String
    , error : Maybe String
    , currentPage : Int
    , itemsPerPage : Int
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url navKey =
    let
        searchText =
            case Parser.parse searchParser url of
                Just text -> text
                Nothing -> ""
    in
    ( { key = navKey
      , documents = []
      , filteredDocuments = []
      , searchText = searchText
      , error = Nothing
      , currentPage = 1
      , itemsPerPage = 12
      }
    , fetchDocuments searchText
    )

searchParser : Parser.Parser (Maybe String)
searchParser =
    Parser.top
        <?> Query.map identity (Query.string "search")



-- UPDATE


type Msg
    = FetchDocuments
    | DocumentsFetched (Result Http.Error (List Document))
    | SearchTextChanged String
    | ClearSearch
    | NextPage
    | PrevPage
    | ApproveDocument String
    | DocumentApproved (Result Http.Error String)
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                searchText =
                    case Parser.parse searchParser url of
                        Just text -> text
                        Nothing -> ""
            in
            ( { model | searchText = searchText }, fetchDocuments searchText )

        FetchDocuments ->
            ( model, fetchDocuments model.searchText )

        ApproveDocument docId ->
            ( model, approveDocument docId )

        DocumentApproved (Ok _) ->
            ( model, fetchDocuments model.searchText )

        DocumentApproved (Err err) ->
            ( { model | error = Just (errorToString err) }, Cmd.none )

        DocumentsFetched (Ok docs) ->
            ( { model | documents = docs, filteredDocuments = docs, error = Nothing }, Cmd.none )

        DocumentsFetched (Err err) ->
            ( { model | error = Just (errorToString err) }, Cmd.none )

        SearchTextChanged text ->
            let
                lowerSearch =
                    String.toLower text

                matchesSearch doc =
                    let
                        notes = String.toLower (Maybe.withDefault "" doc.notes)
                        site = String.toLower (Maybe.withDefault "" doc.site)
                        province = String.toLower (Maybe.withDefault "" doc.province)
                    in
                    String.contains lowerSearch notes
                        || String.contains lowerSearch site
                        || String.contains lowerSearch province

                filteredDocs =
                    if String.isEmpty text then
                        model.documents
                    else
                        List.filter matchesSearch model.documents

                newUrl =
                    if String.isEmpty text then
                        "/surveys"
                    else
                        "/surveys?search=" ++ Url.percentEncode text
            in
            ( { model | searchText = text, filteredDocuments = filteredDocs }
            , Nav.pushUrl model.key newUrl
            )

        ClearSearch ->
            ( { model | searchText = "", filteredDocuments = model.documents }, Cmd.none )

        NextPage ->
            let
                totalPages =
                    (List.length model.filteredDocuments + model.itemsPerPage - 1) // model.itemsPerPage
            in
            ( { model | currentPage = Basics.min (model.currentPage + 1) totalPages }, Cmd.none )

        PrevPage ->
            ( { model | currentPage = Basics.max (model.currentPage - 1) 1 }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        start =
            (model.currentPage - 1) * model.itemsPerPage

        paginatedDocuments =
            List.drop start model.filteredDocuments
                |> List.take model.itemsPerPage
    in
    div [ class "flex flex-col min-h-screen" ]
        [ Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styles.css"
            ]
            []
        , nav [ class "bg-neutral-100 shadow-sm mb-5", Html.Attributes.style "background-color" "rgb(17, 71, 104)" ]
            [ div [ class "container mx-auto px-4 py-3 flex items-center justify-between" ]
                [ div [ class "brand-container" ]
                    [ img [ Html.Attributes.src "images/images.png", Html.Attributes.alt "Logo", class "logo" ] []
                    , div [ class "brand-title" ] [ text "CBC" ]
                    ]
                , ul [ class "nav-items" ]
                    [ li [] [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                    , li [ class "group" ]
                        [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                        , ul [ class "dropdown" ]
                            [ li [] [ a [ href "/downloading", class "dropdown-link" ] [ text "Get Data" ] ]
                            , li [] [ a [ href "/publish", class "dropdown-link" ] [ text "Publish Data" ] ]
                            ]
                        ]
                    , li [ class "group" ]
                        [ a [ href "#", class "nav-link" ] [ text "SURVEYS" ]
                        , ul [ class "dropdown" ]
                            [ li [] [ a [ href "/csvupload", class "dropdown-link" ] [ text "Csv Upload" ] ]
                            , li [] [ a [ href "/survey", class "dropdown-link" ] [ text "Survey Collection" ] ]
                            ]
                        ]
                    , li [] [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                    , li []
                            -- User link
                            [ a [ href "/help", class "nav-link" ] [ text "HELP" ] ]
                    ]
                ]
            ]
        , h1 [ class "survey-title font-bold mx-auto text-5xl text-left mb-6" ] [ text "Survey Collections" ]
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
                ]
            ]
        , div [ class "container mx-auto px-4 py-8 shadow-lg rounded-md bg-slate-200" ]
            [ div [ class "grid document-card grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" ]
                (List.map documentCard paginatedDocuments)
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



-- RENDER DOCUMENT CARD


documentCard : Document -> Html Msg
documentCard doc =
    div [ class "border rounded shadow p-4 bg-white flex-grow" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h2 [ class "text-lg font-semibold" ] [ text ("Collection ID: #" ++ Maybe.withDefault "Unknown" doc.id) ]
            , span [ class "badge active" ] [ text "Active" ]
            ]
        , div [ class "mb-2" ]
            [ text ("Created: " ++ Maybe.withDefault "No Date" doc.date) ]
        , div [ class "mb-2" ]
            [ text ("Location: " ++ Maybe.withDefault "No Site" doc.site) ]
        , div [ class "mb-2" ]
            [ text ("Province: " ++ Maybe.withDefault "No Province" doc.province) ]
        , div [ class "mb-4" ]
            [ text ("Notes: " ++ Maybe.withDefault "No Notes" doc.notes) ]
        , a [ href ("documents/" ++ Maybe.withDefault "Unknown" doc.id), class "btn btn-primary" ] [ text "View Document" ]
        , case (doc.id, doc.approved) of
            (Just id, False) ->  -- Only show the button if approved is False
                button [ onClick (ApproveDocument id), class "btn btn-success" ] [ text "Approve" ]
            _ ->
                text "" -- Do not render the button if the document is already approved
        ]

-- Approved documents
approveDocument : String -> Cmd Msg
approveDocument docId =
    Http.post
        { url = "http://localhost:4000/api/Mongodb/approve_document/" ++ docId
        , body = Http.emptyBody
        , expect = Http.expectString (always (DocumentApproved (Ok docId)))
        }



-- HTTP REQUESTS
fetchDocuments : String -> Cmd Msg
fetchDocuments searchString =
    let
        url =
            if String.isEmpty searchString then
                "http://localhost:4000/api/Mongodb/document"
                -- Fetch all documents initially

            else
                "http://localhost:4000/api/Mongodb/document/search?search=" ++ searchString

        -- Fetch documents based on search
    in
    Http.get
        { url = url
        , expect = Http.expectJson DocumentsFetched (Decode.field "documents" (Decode.list documentDecoder))
        }


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.map6 Document
        (Decode.maybe (Decode.field "_id" Decode.string))
        (Decode.maybe (Decode.field "date" Decode.string))
        (Decode.maybe (Decode.field "notes" Decode.string))
        (Decode.maybe (Decode.field "site" Decode.string))
        (Decode.maybe (Decode.field "province" Decode.string))
        (Decode.maybe (Decode.field "approved" Decode.bool) |> Decode.map (Maybe.withDefault False))  -- New field added for approval status


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


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }