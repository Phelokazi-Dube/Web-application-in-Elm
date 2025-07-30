module Profile exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, href)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline exposing (required)


-- FLAGS

type alias Flags =
    { baseUrl : String
    }


-- MODEL

type alias Document =
    { id : String
    , continent : String
    , continentId : String
    , dataAccessId : String
    , dataSourceId : String
    , dataStatusId : String
    , userLogin : String
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


-- UPDATE

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDocuments (Ok response) ->
            ( { model | documents = response.documents, isAdmin = response.isAdmin }, Cmd.none )

        GotDocuments (Err err) ->
            ( { model | error = Just (httpErrorToString err) }, Cmd.none )


-- VIEW

view : Model -> Html Msg
view model =
    div [ class "container mx-auto p-6" ]
        [ h1 [ class "text-3xl font-bold mb-6" ] [ text "Continents Collection" ]
        , case model.error of
            Just errMsg ->
                div [ class "text-red-600" ] [ text errMsg ]

            Nothing ->
                table [ class "min-w-full table-auto border border-gray-300" ]
                    [ thead [ class "bg-gray-100" ]
                        [ tr []
                            [ thCell "Continent"
                            , thCell "Continent ID"
                            , thCell "Data Access ID"
                            , thCell "Data Source ID"
                            , thCell "Data Status ID"
                            , thCell "Submitted by"
                            , thCell "Document"
                            ]
                        ]
                    , tbody []
                        (List.map viewDocument model.documents)
                    ]
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
        [ tdCell doc.continent
        , tdCell doc.continentId
        , tdCell doc.dataAccessId
        , tdCell doc.dataSourceId
        , tdCell doc.dataStatusId
        , tdCell doc.userLogin
        , td [ class "px-4 py-2 border border-gray-300" ]
            [ a [ href ("/documents/" ++ doc.id ++ "?collection=Continents"), class "text-blue-600 underline" ]
                [ text "View Document" ]
            ]
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


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.succeed Document
        |> required "_id" Decode.string
        |> required "continent" Decode.string
        |> required "continentid" Decode.string
        |> required "dataaccessid" Decode.string
        |> required "datasourceid" Decode.string
        |> required "datastatusid" Decode.string
        |> required "userLogin" Decode.string


-- ERROR HANDLING

httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url -> "Bad URL: " ++ url
        Http.Timeout -> "Request timed out"
        Http.NetworkError -> "Network error"
        Http.BadStatus status -> "Bad response: " ++ String.fromInt status
        Http.BadBody body -> "Decoding error: " ++ body


-- MAIN

main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }
