port module Implementers exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Url


port downloadCsvPort : String -> Cmd msg


port rememberImplementersUrl : String -> Cmd msg


type alias Flags =
    { baseUrl : String
    , csrfToken : String
    , collection : String
    , search : String
    , page : Int
    }


type alias Document =
    { id : String
    , implementerId : Maybe String
    , firstname : Maybe String
    , surname : Maybe String
    , fsname : Maybe String
    , approved : Bool
    }


type alias Response =
    { isAdmin : Bool
    , documents : List Document
    }


type alias Model =
    { documents : List Document
    , searchText : String
    , activeSearch : String
    , currentPage : Int
    , itemsPerPage : Int
    , baseUrl : String
    , csrfToken : String
    , isLoading : Bool
    , error : Maybe String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { documents = []
            , searchText = flags.search
            , activeSearch = String.trim flags.search
            , currentPage = Basics.max 1 flags.page
            , itemsPerPage = 12
            , baseUrl = flags.baseUrl
            , csrfToken = flags.csrfToken
            , isLoading = True
            , error = Nothing
            }
    in
    ( model, searchDocuments model.baseUrl model.activeSearch )


listingUrl : String -> Int -> String
listingUrl search page =
    if String.isEmpty search then
        "/records/implementers?page=" ++ String.fromInt page

    else
        "/records/implementers?search="
            ++ Url.percentEncode search
            ++ "&page="
            ++ String.fromInt page


type Msg
    = SearchChanged String
    | SearchSubmitted
    | ClearSearch
    | NextPage
    | PrevPage
    | DocumentsFetched (Result Http.Error Response)
    | ExportCSV
    | ApproveDocument String
    | DocumentApproved (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SearchChanged text ->
            ( { model | searchText = text }, Cmd.none )

        SearchSubmitted ->
            let
                search =
                    String.trim model.searchText
            in
            ( { model
                | searchText = search
                , activeSearch = search
                , currentPage = 1
                , isLoading = True
                , error = Nothing
              }
            , Cmd.batch
                [ rememberImplementersUrl (listingUrl search 1)
                , searchDocuments model.baseUrl search
                ]
            )

        ClearSearch ->
            ( { model
                | searchText = ""
                , activeSearch = ""
                , currentPage = 1
                , isLoading = True
                , error = Nothing
              }
            , Cmd.batch
                [ rememberImplementersUrl (listingUrl "" 1)
                , searchDocuments model.baseUrl ""
                ]
            )

        DocumentsFetched (Ok response) ->
            let
                totalPages =
                    Basics.max 1
                        ((List.length response.documents + model.itemsPerPage - 1)
                            // model.itemsPerPage
                        )

                page =
                    Basics.min model.currentPage totalPages
            in
            ( { model
                | documents = response.documents
                , currentPage = page
                , error = Nothing
                , isLoading = False
              }
            , if page == model.currentPage then
                Cmd.none

              else
                rememberImplementersUrl (listingUrl model.activeSearch page)
            )

        DocumentsFetched (Err error) ->
            ( { model | error = Just (httpErrorToString error), isLoading = False }
            , Cmd.none
            )

        NextPage ->
            let
                totalPages =
                    Basics.max 1
                        ((List.length model.documents + model.itemsPerPage - 1)
                            // model.itemsPerPage
                        )

                page =
                    Basics.min totalPages (model.currentPage + 1)
            in
            ( { model | currentPage = page }
            , rememberImplementersUrl (listingUrl model.activeSearch page)
            )

        PrevPage ->
            let
                page =
                    Basics.max 1 (model.currentPage - 1)
            in
            ( { model | currentPage = page }
            , rememberImplementersUrl (listingUrl model.activeSearch page)
            )

        ExportCSV ->
            ( model
            , downloadCsvPort
                (model.baseUrl
                    ++ "/api/Mongodb/document/search/export?collection=Implementers"
                    ++ (if String.isEmpty model.activeSearch then
                            ""

                        else
                            "&search=" ++ Url.percentEncode model.activeSearch
                       )
                )
            )

        ApproveDocument id ->
            ( model, approveDocument model id )

        DocumentApproved (Ok _) ->
            ( { model | isLoading = True }
            , searchDocuments model.baseUrl model.activeSearch
            )

        DocumentApproved (Err error) ->
            ( { model | error = Just (httpErrorToString error) }, Cmd.none )


view : Model -> Html Msg
view model =
    let
        start =
            (model.currentPage - 1) * model.itemsPerPage

        visible =
            model.documents |> List.drop start |> List.take model.itemsPerPage

        totalPages =
            Basics.max 1
                ((List.length model.documents + model.itemsPerPage - 1)
                    // model.itemsPerPage
                )
    in
    main_ [ class "collection-page site-content-width animate-fade-in" ]
        [ div [ class "collection-header" ]
            [ div []
                [ h1 [ class "collection-title" ] [ text "Implementers Collection" ]
                , p [ class "collection-description" ]
                    [ text "Browse and manage implementer records (administrators only)." ]
                ]
            , a
                [ class "collection-import-button"
                , href ("/csvupload?collection=Implementers&return="
                    ++ Url.percentEncode (listingUrl model.activeSearch model.currentPage)
                )
                ]
                [ text "Import using CSV" ]
            ]
        , div [ class "collection-search-bar" ]
            [ input
                [ class "collection-search-input"
                , type_ "text"
                , placeholder "Search implementers..."
                , value model.searchText
                , onInput SearchChanged
                ]
                []
            , div [ class "collection-search-actions" ]
                [ button [ class "collection-search-button", onClick SearchSubmitted ]
                    [ text "Search" ]
                , button [ class "collection-clear-button", onClick ClearSearch ]
                    [ text "Clear" ]
                , button [ class "collection-export-button", onClick ExportCSV ]
                    [ text "Export CSV" ]
                ]
            ]
        , case model.error of
            Just error ->
                div [ class "collection-error" ] [ text error ]

            Nothing ->
                text ""
        , if model.isLoading then
            div [ class "collection-loading" ] [ text "Loading implementers..." ]

          else
            div [ class "collection-grid-panel" ]
                [ if List.isEmpty visible then
                    div [ class "collection-empty" ] [ text "No implementers found." ]

                  else
                    div [ class "collection-grid" ]
                        (List.map (documentCard model) visible)
                , div [ class "collection-pagination" ]
                    [ button
                        [ class "collection-pagination-button"
                        , onClick PrevPage
                        , disabled (model.currentPage <= 1)
                        ]
                        [ text "Previous" ]
                    , span [ class "collection-page-number" ]
                        [ text ("Page " ++ String.fromInt model.currentPage ++ " of " ++ String.fromInt totalPages) ]
                    , button
                        [ class "collection-pagination-button"
                        , onClick NextPage
                        , disabled (model.currentPage >= totalPages)
                        ]
                        [ text "Next" ]
                    ]
                ]
        ]


implementerName : Document -> String
implementerName doc =
    let
        fullName =
            [ doc.firstname, doc.surname ]
                |> List.filterMap identity
                |> List.map String.trim
                |> List.filter (\part -> not (String.isEmpty part))
                |> String.join " "

        alternateName =
            doc.fsname
                |> Maybe.withDefault ""
                |> String.trim
    in
    if not (String.isEmpty fullName) then
        fullName

    else if not (String.isEmpty alternateName) then
        alternateName

    else
        "Implementer"


documentCard : Model -> Document -> Html Msg
documentCard model doc =
    div [ class "collection-card animate-fade-in" ]
        [ div [ class "collection-card-heading" ]
            [ h2 [ class "collection-card-title" ] [ text (implementerName doc) ]
            , if doc.approved then
                span [ class "collection-status-active" ] [ text "Active" ]

              else
                span [ class "collection-status-pending" ] [ text "Pending" ]
            ]
        , div [ class "collection-card-details" ]
            [ p []
                [ span [ class "collection-field-label" ] [ text "Implementer ID" ]
                , text (Maybe.withDefault "Not recorded" doc.implementerId)
                ]
            ]
        , div [ class "collection-card-actions" ]
            [ a
                [ class "collection-view-button"
                , href
                    ("/documents/"
                        ++ Url.percentEncode doc.id
                        ++ "?collection=Implementers&return="
                        ++ Url.percentEncode (listingUrl model.activeSearch model.currentPage)
                    )
                ]
                [ text "View Document" ]
            , if doc.approved then
                text ""

              else
                button [ class "collection-approve-button", onClick (ApproveDocument doc.id) ]
                    [ text "Approve" ]
            ]
        ]


searchDocuments : String -> String -> Cmd Msg
searchDocuments baseUrl search =
    let
        url =
            if String.isEmpty (String.trim search) then
                baseUrl ++ "/api/Mongodb/document?collection=Implementers"

            else
                baseUrl
                    ++ "/api/Mongodb/document/search?collection=Implementers&search="
                    ++ Url.percentEncode search
    in
    Http.get
        { url = url
        , expect = Http.expectJson DocumentsFetched responseDecoder
        }


approveDocument : Model -> String -> Cmd Msg
approveDocument model id =
    Http.request
        { method = "POST"
        , headers = [ Http.header "x-csrf-token" model.csrfToken ]
        , url = model.baseUrl ++ "/api/Mongodb/approve_document/" ++ id ++ "?collection=Implementers"
        , body = Http.emptyBody
        , expect = Http.expectString DocumentApproved
        , timeout = Nothing
        , tracker = Nothing
        }


responseDecoder : Decode.Decoder Response
responseDecoder =
    Decode.succeed Response
        |> Pipeline.required "isAdmin" Decode.bool
        |> Pipeline.required "documents" (Decode.list documentDecoder)


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.succeed Document
        |> Pipeline.required "_id" Decode.string
        |> Pipeline.optional "implementerId" (Decode.map Just stringOrNumber) Nothing
        |> Pipeline.optional "firstname" (Decode.nullable Decode.string) Nothing
        |> Pipeline.optional "surname" (Decode.nullable Decode.string) Nothing
        |> Pipeline.optional "fsname" (Decode.nullable Decode.string) Nothing
        |> Pipeline.optional "approved" Decode.bool False


stringOrNumber : Decode.Decoder String
stringOrNumber =
    Decode.oneOf
        [ Decode.string
        , Decode.int |> Decode.map String.fromInt
        , Decode.float |> Decode.map String.fromFloat
        ]


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus code ->
            "Request failed: " ++ String.fromInt code

        Http.BadBody body ->
            "Invalid response: " ++ body


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }