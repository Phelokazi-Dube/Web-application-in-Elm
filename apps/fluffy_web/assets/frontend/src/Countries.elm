module Countries exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, disabled, href)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline exposing (required)



-- MODEL


type alias Flags =
    { csrfToken : String
    , collection : String
    , baseUrl : String
    , searchText : String
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
    }


type alias Model =
    { documents : List Document
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
            , isAdmin = False
            , error = Nothing
            , currentPage = 1
            , itemsPerPage = 18
            , baseUrl = flags.baseUrl
            , isLoading = True
            }
    in
    ( model, fetchDocuments model.baseUrl )



-- MESSAGES


type Msg
    = GotDocuments (Result Http.Error Response)
    | NextPage
    | PrevPage



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDocuments (Ok response) ->
            ( { model | documents = response.documents, isAdmin = response.isAdmin, isLoading = False}, Cmd.none )

        GotDocuments (Err err) ->
            ( { model | error = Just (httpErrorToString err), isLoading = False}, Cmd.none )

        NextPage ->
            let
                totalPages =
                    (List.length model.documents + model.itemsPerPage - 1) // model.itemsPerPage
            in
            ( { model | currentPage = Basics.min (model.currentPage + 1) totalPages }, Cmd.none )

        PrevPage ->
            ( { model | currentPage = Basics.max (model.currentPage - 1) 1 }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        startIndex =
            (model.currentPage - 1) * model.itemsPerPage

        paginatedDocuments =
            model.documents
                |> List.drop startIndex
                |> List.take model.itemsPerPage

        totalPages =
            (List.length model.documents + model.itemsPerPage - 1) // model.itemsPerPage

        isFirstPage =
            model.currentPage == 1

        isLastPage =
            model.currentPage >= totalPages
    in
    div []
        [  if model.isLoading then
            div
                [ class "fixed inset-0 bg-white bg-opacity-70 flex items-center justify-center z-50" ]
                [ div [ class "text-xl font-semibold" ] [ text "⏳ Loading..." ] ]
          else
            text ""
        ,div [ class "container mx-auto p-6 animate-fade-in" ]
            [ div [ class "flex items-center justify-between mb-6" ]
                [ h1 [ class "text-4xl font-extrabold text-emerald-700" ]
                    [ text "🌍 Countries Collection" ]
                , a
                    [ href "/csvupload?collection=Countries"
                    , class "bg-green-600 hover:bg-green-700 text-white font-semibold py-2 px-4 rounded shadow"
                    ]
                    [ text "+ Upload More Countries via CSV" ]
                ]
            , case model.error of
                Just errMsg ->
                    div [ class "text-red-600" ] [ text errMsg ]

                Nothing ->
                    div []
                        [ table [ class "min-w-full table-auto border border-gray-300 mb-6" ]
                            [ thead [ class "bg-gray-100" ]
                                [ tr []
                                    [ thCell "Country ID"
                                    , thCell "Continent ID"
                                    , thCell "Country"
                                    , thCell "Data Source ID"
                                    , thCell "Data Status ID"
                                    , thCell "Data Access ID"
                                    , thCell "Submitted by"
                                    , thCell "Document"
                                    ]
                                ]
                            , tbody []
                                (List.map viewDocument paginatedDocuments)
                            ]
                        , div [ class "pagination mt-4 flex justify-between" ]
                            [ button
                                [ onClick PrevPage
                                , disabled (isFirstPage || model.isLoading)
                                , class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700"
                                ]
                                [ text "Previous" ]
                            , span [ class "px-4 py-2 text-gray-700" ]
                                [ text ("Page " ++ String.fromInt model.currentPage ++ " of " ++ String.fromInt totalPages) ]
                            , button
                                [ onClick NextPage
                                , disabled (isLastPage || model.isLoading)
                                , class "btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700"
                                ]
                                [ text "Next" ]
                            ]
                              ]      ]
            ]


thCell : String -> Html msg
thCell label =
    th [ class "px-4 py-2 text-left font-semibold border border-gray-300" ] [ text label ]


tdCell : String -> Html msg
tdCell value =
    td [ class "px-4 py-2 border border-gray-300" ] [ text value ]


viewDocument : Document -> Html msg
viewDocument doc =
    tr []
        [ tdCell doc.countryId
        , tdCell doc.continentId
        , tdCell doc.country
        , tdCell doc.dataSourceId
        , tdCell doc.dataStatusId
        , tdCell doc.dataAccessId
        , tdCell doc.userLogin
        , td [ class "px-4 py-2 border border-gray-300" ]
            [ a [ href ("/documents/" ++ doc.id ++ "?collection=Countries"), class "text-blue-600 underline" ]
                [ text "View Document" ]
            ]
        ]



-- HTTP


fetchDocuments : String -> Cmd Msg
fetchDocuments baseUrl =
    Http.get
        { url = baseUrl ++ "/api/Mongodb/document?collection=Countries"
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


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.succeed Document
        |> required "_id" Decode.string
        |> required "countryid" Decode.string
        |> required "continentid" Decode.string
        |> required "country" Decode.string
        |> required "datasourceid" Decode.string
        |> required "datastatusid" Decode.string
        |> required "dataaccessid" Decode.string
        |> required "userLogin" Decode.string



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
