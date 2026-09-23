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
    , dataSourceId : String
    , dataStatusId : String
    , dataAccessId : String
    , userLogin : String
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
    div [ class "flex flex-col min-h-screen animate-fade-in" ]
        [ h1
            [ class "survey-title font-bold mx-auto text-5xl text-left mb-6" ]
            [ text "Countries Collection" ]

        , div
            [ class "search-bar container mx-auto flex items-center mb-4 px-4 py-2 border border-neutral-300 rounded-md shadow-sm" ]
            [ input
                [ class "search-input flex-grow px-2 py-1 border rounded-md"
                , type_ "text"
                , placeholder "Search by text"
                , value model.searchText
                , onInput SearchTextChanged
                ]
                []

            , div [ class "this flex space-x-2 ml-auto" ]
                [ button
                    [ class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700"
                    , onClick FetchDocuments
                    ]
                    [ text "Search" ]

                , button
                    [ class "clear-btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700"
                    , onClick ClearSearch
                    ]
                    [ text "X" ]

                , button
                    [ class "btn bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-500"
                    , onClick ExportCSV
                    ]
                    [ text "Export CSV" ]
                ]
            ]

        , if model.isLoading then
            div
                [ class "text-center py-8 text-xl font-semibold" ]
                [ text "Loading..." ]

          else
            text ""

        , div
            [ class "container mx-auto px-4 py-8 shadow-lg rounded-md bg-slate-200 animate-fade-in" ]
            [ if List.isEmpty paginatedDocuments && not model.isLoading then
                div
                    [ class "text-center py-8 text-gray-600" ]
                    [ text "No countries found." ]

              else
                div
                    [ class "grid document-card grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" ]
                    (List.map
                        (documentCard model.isAdmin)
                        paginatedDocuments
                    )

            , div
                [ class "pagination mt-4 flex justify-between" ]
                [ button
                    [ onClick PrevPage
                    , disabled (model.currentPage == 1)
                    , class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700"
                    ]
                    [ text "Previous" ]

                , span
                    [ class "px-4 py-2 text-gray-700" ]
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
                    , class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700"
                    ]
                    [ text "Next" ]
                ]
            ]

        , case model.error of
            Just errorMsg ->
                div
                    [ class "error-msg text-red-500 mt-4" ]
                    [ text ("Error: " ++ errorMsg) ]

            Nothing ->
                text ""
        ]



-- DOCUMENT CARD


documentCard : Bool -> Document -> Html Msg
documentCard isAdmin doc =
    div
        [ class "border rounded shadow p-4 bg-white flex-grow animate-fade-in" ]
        [ div
            [ class "flex items-center justify-between mb-4" ]
            [ h2
                [ class "text-lg font-semibold" ]
                [ text ("Country: " ++ doc.country) ]

            , if doc.approved then
                span [ class "badge active" ]
                    [ text "Active" ]

              else
                text ""
            ]

        , div [ class "mb-2" ]
            [ text ("Country ID: " ++ doc.countryId) ]

        , div [ class "mb-2" ]
            [ text ("Continent ID: " ++ doc.continentId) ]

        , div [ class "mb-4" ]
            [ text ("Submitted by: " ++ doc.userLogin) ]

        , a
            [ href
                ("/documents/"
                    ++ doc.id
                    ++ "?collection=Countries"
                )
            , class "btn btn-primary"
            ]
            [ text "View Document" ]

        , case ( doc.approved, isAdmin ) of
            ( False, True ) ->
                button
                    [ onClick (ApproveDocument doc.id)
                    , class "btn btn-success"
                    ]
                    [ text "Approve" ]

            ( False, False ) ->
                span
                    [ class "mb-2 text-red" ]
                    [ text " NOT YET APPROVED" ]

            _ ->
                text ""
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
        |> Pipeline.required "countryid" Decode.string
        |> Pipeline.required "continentid" Decode.string
        |> Pipeline.required "country" Decode.string
        |> Pipeline.required "datasourceid" Decode.string
        |> Pipeline.required "datastatusid" Decode.string
        |> Pipeline.required "dataaccessid" Decode.string
        |> Pipeline.required "userLogin" Decode.string
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