port module CombinedSurveys exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Url


-- Keep search and pagination in the browser URL while preserving
-- the Phoenix navbar/footer provided outside Elm.
port rememberCombinedUrl : String -> Cmd msg





-- MODEL


type alias Document =
    { id : Maybe String
    , surveyId : Maybe String
    , date : Maybe String
    , year : Maybe String
    , siteId : Maybe String
    , surveyType : Maybe String
    , weed : Maybe String
    , remarks : Maybe String
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
    , search : String
    , page : Int
    }


type alias Model =
    { documents : List Document
    , searchText : String
    , activeSearch : String
    , error : Maybe String
    , currentPage : Int
    , itemsPerPage : Int
    , baseUrl : String
    , isLoading : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { documents = []
            , searchText = flags.search
            , activeSearch = String.trim flags.search
            , error = Nothing
            , currentPage = Basics.max 1 flags.page
            , itemsPerPage = 12
            , baseUrl = flags.baseUrl
            , isLoading = True
            }
    in
    ( model, fetchDocuments model model.activeSearch )


-- UPDATE


combinedUrl : String -> Int -> String
combinedUrl search page =
    if String.isEmpty search then
        "/combined?page=" ++ String.fromInt page

    else
        "/combined?search="
            ++ Url.percentEncode search
            ++ "&page="
            ++ String.fromInt page



type Msg
    = FetchDocuments
    | DocumentsFetched (Result Http.Error (List Document))
    | SearchTextChanged String
    | ClearSearch
    | NextPage
    | PrevPage


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchDocuments ->
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
                [ rememberCombinedUrl (combinedUrl search 1)
                , fetchDocuments model search
                ]
            )

        DocumentsFetched (Ok docs) ->
            let
                totalPages =
                    Basics.max 1
                        ((List.length docs + model.itemsPerPage - 1)
                            // model.itemsPerPage
                        )

                page =
                    Basics.min model.currentPage totalPages
            in
            ( { model
                | documents = docs
                , currentPage = page
                , error = Nothing
                , isLoading = False
              }
            , if page == model.currentPage then
                Cmd.none

              else
                rememberCombinedUrl (combinedUrl model.activeSearch page)
            )

        DocumentsFetched (Err err) ->
            ( { model
                | error = Just (errorToString err)
                , isLoading = False
              }
            , Cmd.none
            )

        SearchTextChanged searchText ->
            ( { model | searchText = searchText }
            , Cmd.none
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
                [ rememberCombinedUrl (combinedUrl "" 1)
                , fetchDocuments model ""
                ]
            )

        NextPage ->
            let
                totalPages =
                    Basics.max 1
                        ((List.length model.documents + model.itemsPerPage - 1)
                            // model.itemsPerPage
                        )

                page =
                    Basics.min (model.currentPage + 1) totalPages
            in
            ( { model | currentPage = page }
            , rememberCombinedUrl (combinedUrl model.activeSearch page)
            )

        PrevPage ->
            let
                page =
                    Basics.max 1 (model.currentPage - 1)
            in
            ( { model | currentPage = page }
            , rememberCombinedUrl (combinedUrl model.activeSearch page)
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
            List.drop start model.documents
                |> List.take model.itemsPerPage

        totalPages =
            Basics.max 1
                ((List.length model.documents + model.itemsPerPage - 1)
                    // model.itemsPerPage
                )
    in
    div [ class "collection-page site-content-width animate-fade-in" ]
        [ div [ class "collection-header" ]
            [ div []
                [ h1 [ class "collection-title" ] [ text "Combined Survey Data" ]
                , p [ class "collection-description" ]
                    [ text "Explore survey information and its associated CBC records." ]
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
                [ button [ class "collection-search-button", onClick FetchDocuments ] [ text "Search" ]
                , button [ class "collection-clear-button", onClick ClearSearch ] [ text "Clear" ]
                ]
            ]
        , case model.error of
            Just err ->
                div [ class "collection-error" ] [ text err ]

            Nothing ->
                text ""
        , if model.isLoading then
            div [ class "collection-loading" ] [ text "Loading survey records..." ]

          else
            div [ class "collection-grid-panel" ]
                [ if List.isEmpty paginatedDocuments then
                    div [ class "collection-empty" ] [ text "No survey records found." ]

                  else
                    div [ class "collection-grid" ]
                        (List.map (documentCard model) paginatedDocuments)
                , div [ class "collection-pagination" ]
                    [ button
                        [ onClick PrevPage
                        , disabled (model.currentPage <= 1)
                        , class "collection-pagination-button"
                        ]
                        [ text "Previous" ]
                    , span [ class "collection-page-number" ]
                        [ text
                            ("Page " ++ String.fromInt model.currentPage ++ " of " ++ String.fromInt totalPages)
                        ]
                    , button
                        [ onClick NextPage
                        , disabled (model.currentPage >= totalPages)
                        , class "collection-pagination-button"
                        ]
                        [ text "Next" ]
                    ]
                ]
        ]

-- RENDER DOCUMENT CARD


documentCard : Model -> Document -> Html Msg
documentCard model doc =
    let
        legacySurveyId =
            doc.surveyId
                |> Maybe.andThen (\v -> if String.trim v == "" then Nothing else Just v)

        displayId =
            case legacySurveyId of
                Just surveyId ->
                    "Survey ID " ++ surveyId

                Nothing ->
                    "Document ID " ++ Maybe.withDefault "Unknown" doc.id

        detailReference =
            Maybe.withDefault (Maybe.withDefault "" doc.id) legacySurveyId
    in
    div [ class "collection-card animate-fade-in" ]
        [ div [ class "collection-card-heading" ]
            [ div []
                [ h2 [ class "collection-card-title survey-card-title" ] [ text "Survey" ]
                , p [ class "survey-card-id" ] [ text displayId ]
                ]
            , if doc.approved then
                span [ class "collection-status-active" ] [ text "Active" ]

              else
                span [ class "collection-status-pending" ] [ text "Pending" ]
            ]
        , div [ class "collection-card-details" ]
            [ p []
                [ span [ class "collection-field-label" ] [ text "Date / Year" ]
                , span [] [ text (Maybe.withDefault "Not recorded" (orElse doc.year doc.date)) ]
                ]
            , p []
                [ span [ class "collection-field-label" ] [ text "Site" ]
                , span []
                    [ text
                        (Maybe.withDefault "Not recorded"
                            (orElse doc.siteId (orElse doc.sitename doc.site))
                        )
                    ]
                ]
            , p []
                [ span [ class "collection-field-label" ] [ text "Province" ]
                , span [] [ text (Maybe.withDefault "Not recorded" doc.province) ]
                ]
            , p []
                [ span [ class "collection-field-label" ] [ text "Notes / Remarks" ]
                , span []
                    [ text
                        (Maybe.withDefault "Not recorded"
                            (orElse doc.remarks (orElse doc.description doc.notes))
                        )
                    ]
                ]
            ]
        , div [ class "collection-card-actions" ]
            [ if detailReference == "" then
                span [ class "collection-empty" ] [ text "No document identifier available" ]

              else
                a
                    [ href ("/surveys/" ++ Url.percentEncode detailReference
                            ++ "?return="
                            ++ Url.percentEncode (combinedUrl model.activeSearch model.currentPage)
                        )
                    , class "collection-view-button"
                    ]
                    [ text "View Survey Details" ]
            ]
        ]


-- HTTP REQUESTS


fetchDocuments : Model -> String -> Cmd Msg
fetchDocuments model searchString =
    let
        trimmedSearch =
            String.trim searchString

        url =
            if String.isEmpty trimmedSearch then
                model.baseUrl ++ "/api/Mongodb/document?collection=Surveys"

            else
                model.baseUrl
                    ++ "/api/Mongodb/document/search?collection=Surveys&search="
                    ++ Url.percentEncode trimmedSearch
    in
    Http.get
        { url = url
        , expect =
            Http.expectJson DocumentsFetched
                (Decode.field "documents" (Decode.list documentDecoder))
        }


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
        |> Pipeline.custom (Decode.maybe (Decode.field "_id" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "surveyId" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "date" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "year" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "siteId" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "surveyType" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "weed" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "remarks" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "notes" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "description" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "site" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "sitename" stringOrNumber))
        |> Pipeline.custom (Decode.maybe (Decode.field "province" stringOrNumber))
        |> Pipeline.optional "approved" Decode.bool False


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
        , view = viewContent
        , subscriptions = subscriptions
        }