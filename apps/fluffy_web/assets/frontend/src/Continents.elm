module Continents exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class, href)
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline exposing (required)



-- FLAGS


type alias Flags =
    { baseUrl : String
    , csrfToken : String
    , collection : String
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
    div [ class "container mx-auto p-6 animate-fade-in" ]
        [ h1
            [ class "survey-title font-bold text-5xl text-left mb-6" ]
            [ text "Continents Collection" ]

        , case model.error of
            Just errMsg ->
                div [ class "text-red-600 mb-4" ]
                    [ text errMsg ]

            Nothing ->
                div
                    [ class "px-4 py-8 shadow-lg rounded-md bg-slate-200 animate-fade-in" ]
                    [ div
                        [ class "grid document-card grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" ]
                        (List.map viewDocument model.documents)
                    ]
        ]


viewDocument : Document -> Html msg
viewDocument doc =
    div
        [ class "border rounded shadow p-4 bg-white flex-grow animate-fade-in" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h2 [ class "text-lg font-semibold" ]
                [ text ("Continent: " ++ doc.continent) ]
            ]

        , div [ class "mb-2" ]
            [ text ("Continent ID: " ++ doc.continentId) ]

        , div [ class "mb-4" ]
            [ text ("Submitted by: " ++ doc.userLogin) ]

        , a
            [ href
                ("/documents/"
                    ++ doc.id
                    ++ "?collection=Continents"
                )
            , class "btn btn-primary"
            ]
            [ text "View Document" ]
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
