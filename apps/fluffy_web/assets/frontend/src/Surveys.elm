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
    { baseUrl : String
    , csrfToken : String
    , collection : String
    }


type alias QueryParams =
    { search : Maybe String
    , page : Maybe Int
    }


type alias Model =
    { key : Nav.Key
    , documents : List Document
    , filteredDocuments : List Document
    , searchText : String
    , error : Maybe String
    , currentPage : Int
    , itemsPerPage : Int
    , adminUser : Bool
    , baseUrl : String
    }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url navKey =
    let
        params =
            case Parser.parse searchParser url of
                Just queryParams ->
                    queryParams

                Nothing ->
                    { search = Nothing
                    , page = Nothing
                    }

        searchText =
            Maybe.withDefault "" params.search

        currentPage =
            Maybe.withDefault 1 params.page

        model =
            { key = navKey
            , documents = []
            , filteredDocuments = []
            , searchText = searchText
            , error = Nothing
            , currentPage = currentPage
            , itemsPerPage = 12
            , adminUser = False
            , baseUrl = flags.baseUrl
            }
    in
    ( model, fetchDocuments model searchText )


searchParser : Parser.Parser (QueryParams -> a) a
searchParser =
    Parser.s "survey"
        <?> Query.map2 QueryParams
                (Query.string "search")
                (Query.int "page")



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
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | ExportCSV


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    case Parser.parse (Parser.s "survey") url of
                        Just _ ->
                            ( model, Nav.pushUrl model.key (Url.toString url) )

                        _ ->
                            ( model, Nav.load (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                params =
                    case Parser.parse searchParser url of
                        Just queryParams ->
                            queryParams

                        Nothing ->
                            { search = Nothing
                            , page = Nothing
                            }

                searchText =
                    Maybe.withDefault "" params.search

                currentPage =
                    Maybe.withDefault 1 params.page

                updatedModel =
                    { model
                        | searchText = searchText
                        , currentPage = currentPage
                    }
            in
            ( updatedModel, fetchDocuments updatedModel searchText )

        FetchDocuments ->
            ( model, fetchDocuments model model.searchText )

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

                newUrl =
                    if String.isEmpty text then
                        "/survey?page=1"

                    else
                        "/survey?search=" ++ Url.percentEncode text ++ "&page=1"
            in
            ( { model | searchText = text, filteredDocuments = filteredDocs, currentPage = 1 }
            , Nav.replaceUrl model.key newUrl
            )

        ClearSearch ->
            ( { model | searchText = "", filteredDocuments = model.documents, currentPage = 1 } 
            , Nav.replaceUrl model.key "/survey?page=1" )

        NextPage ->
            let
                totalPages =
                    (List.length model.filteredDocuments + model.itemsPerPage - 1) // model.itemsPerPage

                newPage =
                    Basics.min (model.currentPage + 1) totalPages

                newUrl =
                    if String.isEmpty model.searchText then
                        "/survey?page=" ++ String.fromInt newPage

                    else
                        "/survey?search=" ++ Url.percentEncode model.searchText ++ "&page=" ++ String.fromInt newPage
            in
            ( { model | currentPage = newPage }, Nav.replaceUrl model.key newUrl )

        PrevPage ->
            let
                newPage =
                    Basics.max (model.currentPage - 1) 1

                newUrl =
                    if String.isEmpty model.searchText then
                        "/survey?page=" ++ String.fromInt newPage

                    else
                        "/survey?search=" ++ Url.percentEncode model.searchText ++ "&page=" ++ String.fromInt newPage
            in
            ( { model | currentPage = newPage }, Nav.replaceUrl model.key newUrl )

        ExportCSV ->
            ( model
            , downloadCsvPort
                (model.baseUrl
                    ++ "/api/Mongodb/document/search/export"
                    ++ (if model.searchText /= "" then
                            "?search=" ++ Url.percentEncode model.searchText

                        else
                            ""
                       )
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
    div [ class "animate-fade-in" ]
        [ Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "/assets/app.css"
            ]
            []
        , nav
            [ class "survey-nav" ]
            [ div [ class "site-content-width survey-nav-inner" ]
                [ div [ class "brand-container" ]
                    [ img
                        [ Html.Attributes.src "/images/images.png"
                        , Html.Attributes.alt "Logo"
                        , class "logo"
                        ]
                        []
                    , div [ class "brand-title" ] [ text "CBC" ]
                    ]
                , ul [ class "nav-items" ]
                    [ li []
                        [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                    , li [ class "group" ]
                        [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                        , ul [ class "dropdown" ]
                            [ li []
                                [ a [ href "/survey", class "dropdown-link" ]
                                    [ text "Survey Data" ]
                                ]
                            , li []
                                [ a [ href "/publish", class "dropdown-link" ]
                                    [ text "Publish Data" ]
                                ]
                            ]
                        ]
                    , li []
                        [ a [ href "/records", class "nav-link" ] [ text "RECORDS" ] ]
                    , li []
                        [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                    , li []
                        [ a [ href "/help", class "nav-link" ] [ text "HELP" ] ]
                    ]
                ]
            ]
        , main_ [ class "collection-page site-content-width" ]
            [ div [ class "collection-header" ]
                [ div []
                    [ h1 [ class "collection-title" ]
                        [ text "Survey Collections" ]
                    , p [ class "collection-description" ]
                        [ text "Browse and search biological control survey records." ]
                    ]
                ]
            , div [ class "collection-search-bar" ]
                [ input
                    [ class "collection-search-input"
                    , type_ "text"
                    , placeholder "Search survey records"
                    , value model.searchText
                    , onInput SearchTextChanged
                    ]
                    []
                , div [ class "collection-search-actions" ]
                    [ button
                        [ class "collection-search-button"
                        , onClick FetchDocuments
                        ]
                        [ text "Search" ]
                    , button
                        [ class "collection-clear-button"
                        , onClick ClearSearch
                        ]
                        [ text "Clear" ]
                    , button
                        [ class "collection-export-button"
                        , onClick ExportCSV
                        ]
                        [ text "Export CSV" ]
                    ]
                ]
            , case model.error of
                Just errorMsg ->
                    div [ class "collection-error" ]
                        [ text ("Error: " ++ errorMsg) ]

                Nothing ->
                    text ""
            , div [ class "collection-grid-panel" ]
                [ if List.isEmpty paginatedDocuments then
                    div [ class "collection-empty" ]
                        [ text "No survey records found." ]

                  else
                    div [ class "collection-grid" ]
                        (List.map
                            (documentCard model.adminUser)
                            paginatedDocuments
                        )
                , div [ class "collection-pagination" ]
                    [ button
                        [ onClick PrevPage
                        , disabled (model.currentPage == 1)
                        , class "collection-pagination-button"
                        ]
                        [ text "Previous" ]
                    , span [ class "collection-page-number" ]
                        [ text ("Page " ++ String.fromInt model.currentPage) ]
                    , button
                        [ onClick NextPage
                        , disabled
                            ((model.currentPage * model.itemsPerPage)
                                >= List.length model.filteredDocuments
                            )
                        , class "collection-pagination-button"
                        ]
                        [ text "Next" ]
                    ]
                ]
            ]
        , footer [ class "footer" ]
            [ div [ class "site-content-width" ]
                [ div [ class "footer-content" ]
                    [ div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "CBC" ]
                        , p [ class "footer-text" ]
                            [ text "Enhancing access to biological control data" ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Quick Links" ]
                        , ul []
                            [ li []
                                [ a [ href "#", class "footer-link" ]
                                    [ text "Privacy Policy" ]
                                ]
                            , li []
                                [ a [ href "#", class "footer-link" ]
                                    [ text "Terms of Service" ]
                                ]
                            , li []
                                [ a [ href "/contact", class "footer-link" ]
                                    [ text "Contact Us" ]
                                ]
                            ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Connect With Us" ]
                        , div [ class "social-icons" ]
                            [ a
                                [ href "/api/facebook"
                                , class "fa fa-facebook"
                                , target "_blank"
                                , rel "noopener noreferrer"
                                , attribute "aria-label" "CBC on Facebook"
                                , title "Facebook"
                                ]
                                []
                            , a
                                [ href "/api/x"
                                , class "fa fa-twitter"
                                , target "_blank"
                                , rel "noopener noreferrer"
                                , attribute "aria-label" "CBC on X"
                                , title "X"
                                ]
                                []
                            , a
                                [ href "/api/instagram"
                                , class "fa fa-instagram"
                                , target "_blank"
                                , rel "noopener noreferrer"
                                , attribute "aria-label" "CBC on Instagram"
                                , title "Instagram"
                                ]
                                []
                            , a
                                [ href "/api/linkedIn"
                                , class "fa fa-linkedin"
                                , target "_blank"
                                , rel "noopener noreferrer"
                                , attribute "aria-label" "CBC on LinkedIn"
                                , title "LinkedIn"
                                ]
                                []
                            ]
                        ]
                    ]
                , div [ class "footer-credits" ]
                    [ p []
                        [ text "© 2025 Center for Biological Control. All rights reserved." ]
                    ]
                ]
            ]
        ]

view : Model -> Browser.Document Msg
view model =
    { title = "Center for Biological Control Data Portal"
    , body = [ viewContent model ]
    }



-- RENDER DOCUMENT CARD


documentCard : Bool -> Document -> Html Msg
documentCard isAdmin doc =
    div [ class "collection-card animate-fade-in" ]
        [ div [ class "collection-card-heading" ]
            [ div []
                [ h2 [ class "collection-card-title survey-card-title" ]
                    [ text "Survey" ]
                , p [ class "survey-card-id" ]
                    [ span [ class "survey-card-id-label" ]
                        [ text "ID " ]
                    , text (Maybe.withDefault "Unknown" doc.id)
                    ]
                ]
            , if doc.approved then
                span [ class "collection-status-active" ]
                    [ text "Active" ]

              else
                span [ class "collection-status-pending" ]
                    [ text "Pending" ]
            ]
        , div [ class "collection-card-details" ]
            [ p []
                [ span [ class "collection-field-label" ]
                    [ text "Created" ]
                , span []
                    [ text (Maybe.withDefault "No Date" doc.date) ]
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Location" ]
                , span []
                    [ text
                        (Maybe.withDefault "No Site"
                            (orElse doc.sitename doc.site)
                        )
                    ]
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Province" ]
                , span []
                    [ text
                        (Maybe.withDefault "No Province" doc.province)
                    ]
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Notes" ]
                , span []
                    [ text
                        (Maybe.withDefault "No Notes"
                            (orElse doc.description doc.notes)
                        )
                    ]
                ]
            ]
        , div [ class "collection-card-actions" ]
            ([ a
                [ href
                    ("/documents/"
                        ++ Maybe.withDefault "Unknown" doc.id
                        ++ "?collection=Surveys"
                    )
                , class "collection-view-button"
                ]
                [ text "View Document" ]
             ]
                ++ (case ( doc.id, doc.approved, isAdmin ) of
                        ( Just id, False, True ) ->
                            [ button
                                [ onClick (ApproveDocument id)
                                , class "collection-approve-button"
                                ]
                                [ text "Approve" ]
                            ]

                        _ ->
                            []
                   )
            )
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

stringOrNumber : Decode.Decoder String
stringOrNumber =
    Decode.oneOf
        [ Decode.string
        , Decode.int |> Decode.map String.fromInt
        , Decode.float |> Decode.map String.fromFloat
        , Decode.null ""
        ]


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.map8 Document
        (Decode.maybe (Decode.field "_id" stringOrNumber))
        (Decode.maybe (Decode.field "date" stringOrNumber))
        (Decode.maybe (Decode.field "notes" stringOrNumber))
        (Decode.maybe (Decode.field "description" stringOrNumber))
        (Decode.maybe (Decode.field "site" stringOrNumber))
        (Decode.maybe (Decode.field "sitename" stringOrNumber))
        (Decode.maybe (Decode.field "province" stringOrNumber))
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
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
