port module Countries exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Url


port downloadCsvPort : String -> Cmd msg



-- MODEL


type alias Flags =
    { baseUrl : String
    , csrfToken : String
    , collection : String
    }


type alias Document =
    { id : String
    , countryId : String
    , continentId : String
    , country : String
    , dataSourceId : Int
    , dataStatusId : Int
    , dataAccessId : Int
    , userLogin : Maybe String
    , approved : Bool
    }


type alias Model =
    { documents : List Document
    , searchText : String
    , isAdmin : Bool
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
            , searchText = ""
            , isAdmin = False
            , error = Nothing
            , currentPage = 1
            , itemsPerPage = 12
            , baseUrl = flags.baseUrl
            , isLoading = True
            }
    in
    ( model, fetchDocuments model.baseUrl )



-- MESSAGES


type Msg
    = FetchDocuments
    | GotDocuments (Result Http.Error Response)
    | SearchTextChanged String
    | ClearSearch
    | NextPage
    | PrevPage
    | ApproveDocument String
    | DocumentApproved (Result Http.Error String)
    | ExportCSV



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchDocuments ->
            ( { model
                | currentPage = 1
                , isLoading = True
                , error = Nothing
              }
            , searchDocuments model.baseUrl model.searchText
            )

        GotDocuments (Ok response) ->
            ( { model
                | documents = response.documents
                , isAdmin = response.isAdmin
                , error = Nothing
                , isLoading = False
              }
            , Cmd.none
            )

        GotDocuments (Err err) ->
            ( { model
                | error = Just (httpErrorToString err)
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
                , currentPage = 1
                , isLoading = True
                , error = Nothing
              }
            , fetchDocuments model.baseUrl
            )

        NextPage ->
            let
                totalPages =
                    Basics.max 1
                        ((List.length model.documents
                            + model.itemsPerPage
                            - 1
                         )
                            // model.itemsPerPage
                        )

                nextPage =
                    Basics.min
                        (model.currentPage + 1)
                        totalPages
            in
            ( { model | currentPage = nextPage }
            , Cmd.none
            )

        PrevPage ->
            let
                previousPage =
                    Basics.max
                        (model.currentPage - 1)
                        1
            in
            ( { model | currentPage = previousPage }
            , Cmd.none
            )

        ApproveDocument docId ->
            ( model
            , approveDocument model docId
            )

        DocumentApproved (Ok _) ->
            ( { model | isLoading = True }
            , searchDocuments model.baseUrl model.searchText
            )

        DocumentApproved (Err err) ->
            ( { model
                | error = Just (httpErrorToString err)
                , isLoading = False
              }
            , Cmd.none
            )

        ExportCSV ->
            ( model
            , downloadCsvPort
                (model.baseUrl
                    ++ "/api/Mongodb/document/search/export?collection=Countries"
                    ++ (if String.trim model.searchText /= "" then
                            "&search="
                                ++ Url.percentEncode model.searchText

                        else
                            ""
                       )
                )
            )



-- VIEW


view : Model -> Html Msg
view model =
    let
        start =
            (model.currentPage - 1) * model.itemsPerPage

        paginatedDocuments =
            model.documents
                |> List.drop start
                |> List.take model.itemsPerPage

        totalPages =
            Basics.max 1
                ((List.length model.documents
                    + model.itemsPerPage
                    - 1
                 )
                    // model.itemsPerPage
                )
    in
    div [ class "collection-page site-content-width animate-fade-in" ]
        [ div [ class "collection-header" ]
            [ div []
                [ h1 [ class "collection-title" ]
                    [ text "Countries Collection" ]
                , p [ class "collection-description" ]
                    [ text "Browse and manage country reference data." ]
                ]
            , a
                [ href "/csvupload?collection=Countries"
                , class "collection-import-button"
                ]
                [ text "Import using CSV" ]
            ]

        , div [ class "collection-search-bar" ]
            [ input
                [ class "collection-search-input"
                , type_ "text"
                , placeholder "Search countries..."
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
                    [ text errorMsg ]

            Nothing ->
                text ""

        , if model.isLoading then
            div [ class "collection-loading" ]
                [ text "Loading countries..." ]

          else
            div [ class "collection-grid-panel" ]
                [ if List.isEmpty paginatedDocuments then
                    div [ class "collection-empty" ]
                        [ text "No countries found." ]

                  else
                    div [ class "collection-grid" ]
                        (List.map
                            (documentCard model.isAdmin)
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
                        [ text
                            ("Page "
                                ++ String.fromInt model.currentPage
                                ++ " of "
                                ++ String.fromInt totalPages
                            )
                        ]

                    , button
                        [ onClick NextPage
                        , disabled
                            ((model.currentPage * model.itemsPerPage)
                                >= List.length model.documents
                            )
                        , class "collection-pagination-button"
                        ]
                        [ text "Next" ]
                    ]
                ]
        ]


-- DOCUMENT CARD


documentCard : Bool -> Document -> Html Msg
documentCard isAdmin doc =
    div [ class "collection-card" ]
        [ div [ class "collection-card-heading" ]
            [ h2 [ class "collection-card-title" ]
                [ text doc.country ]

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
                    [ text "Country ID" ]
                , text doc.countryId
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Continent ID" ]
                , text doc.continentId
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Data Access ID" ]
                , text (String.fromInt doc.dataAccessId)
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Data Source ID" ]
                , text (String.fromInt doc.dataSourceId)
                ]
            , p []
                [ span [ class "collection-field-label" ]
                    [ text "Data Status ID" ]
                , text (String.fromInt doc.dataStatusId)
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

        , div [ class "collection-card-actions" ]
            [ a
                [ href
                    ("/documents/"
                        ++ doc.id
                        ++ "?collection=Countries"
                    )
                , class "collection-view-button"
                ]
                [ text "View Document" ]

            , case ( doc.approved, isAdmin ) of
                ( False, True ) ->
                    button
                        [ onClick (ApproveDocument doc.id)
                        , class "collection-approve-button"
                        ]
                        [ text "Approve" ]

                _ ->
                    text ""
            ]
        ]


-- APPROVE DOCUMENT


approveDocument : Model -> String -> Cmd Msg
approveDocument model docId =
    Http.post
        { url =
            model.baseUrl
                ++ "/api/Mongodb/approve_document/"
                ++ docId
                ++ "?collection=Countries"
        , body = Http.emptyBody
        , expect = Http.expectString DocumentApproved
        }



-- HTTP


fetchDocuments : String -> Cmd Msg
fetchDocuments baseUrl =
    Http.get
        { url =
            baseUrl
                ++ "/api/Mongodb/document?collection=Countries"
        , expect =
            Http.expectJson GotDocuments responseDecoder
        }


searchDocuments : String -> String -> Cmd Msg
searchDocuments baseUrl searchText =
    let
        url =
            if String.isEmpty (String.trim searchText) then
                baseUrl
                    ++ "/api/Mongodb/document?collection=Countries"

            else
                baseUrl
                    ++ "/api/Mongodb/document/search?collection=Countries&search="
                    ++ Url.percentEncode searchText
    in
    Http.get
        { url = url
        , expect =
            Http.expectJson GotDocuments responseDecoder
        }


type alias Response =
    { isAdmin : Bool
    , documents : List Document
    }


responseDecoder : Decode.Decoder Response
responseDecoder =
    Decode.succeed Response
        |> Pipeline.required "isAdmin" Decode.bool
        |> Pipeline.required "documents"
            (Decode.list documentDecoder)


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.succeed Document
        |> Pipeline.required "_id" Decode.string
        |> Pipeline.required "countryId" Decode.string
        |> Pipeline.required "continentId" Decode.string
        |> Pipeline.required "country" Decode.string
        |> Pipeline.required "dataSourceId" Decode.int
        |> Pipeline.required "dataStatusId" Decode.int
        |> Pipeline.required "dataAccessId" Decode.int
        |> Pipeline.optional "userLogin" (Decode.map Just Decode.string) Nothing
        |> Pipeline.optional "approved" Decode.bool False



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
        , subscriptions = subscriptions
        , view = view
        }
