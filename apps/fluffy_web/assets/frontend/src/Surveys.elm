module Surveys exposing (..)
import Browser exposing (element)
import Browser
import Html exposing (Html, div, table, thead, tbody, tr, th, td, a, text, node)
import Html exposing (..)
import Html.Attributes exposing (id, href, class, type_, name, placeholder, attribute)
import Http
import Json.Decode as Decode
import Html.Events exposing (onClick)


-- MODEL

type alias Document =
    { id : String
    , date : Maybe String
    , notes : Maybe String
    }

type alias Model =
    { documents : List Document
    , error : Maybe String
    }

init : (Model, Cmd Msg)
init =
    ( { documents = []
      , error = Nothing
      }
    , fetchDocuments
    )


-- UPDATE

type Msg
    = FetchDocuments
    | DocumentsFetched (Result Http.Error (List Document))


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        FetchDocuments ->
            ( model, fetchDocuments )

        DocumentsFetched (Ok docs) ->
            ( { model | documents = docs, error = Nothing }, Cmd.none )

        DocumentsFetched (Err err) ->
            ( { model | error = Just (errorToString err) }, Cmd.none )


-- VIEW

view : Model -> Html Msg
view model =
    div [ class "main" ]
        [ nav [ class "navbar" ]
          [ div [ class "logo" ]
              [ h2 [] [ text "CBC" ]
              ]
          , ul []
              [ li []
                  [ a [ href "/home" ] [ text "HOME" ]
                  ]
              , li []
                  [ a [ href "/sites" ] [ text "SITES" ]
                  ]
              , li []
                  [ a [ href "#" ] [ text "DATA" ]
                  , ul []
                      [ li []
                          [ a [ href "/downloading" ] [ text "Get Data" ]
                          ]
                      , li []
                          [ a [ href "/publish" ] [ text "Publish Data" ]
                          ]
                      ]
                  ]
              , li []
                  [ a [ href "#" ] [ text "SURVEYS" ]
                  , ul []
                      [ li []
                          [ a [ href "#" ] [ text "Map" ]
                          ]
                      , li []
                          [ a [ href "/surveys" ] [ text "Survey Collection" ]
                          ]
                      ]
                  ]
              , li []
                  [ a [ href "/contact" ] [ text "CONTACT" ]
                  ]
              ]
          , div [ class "search" ]
              [ input [ class "srch", type_ "search", name "search", placeholder "Type To text" ] []
              , button [ class "btn" ] [ text "Search" ]
              ]
          ]
      , div [ class "table-section" ]
              [ h1 [] [ text "Observations" ]
              , p [] [ text "These are all the observations collected." ]
              , table []
                  [ thead []
                      [ tr []
                          [ th [] [ text "Document ID" ]
                          , th [] [ text "Date" ]
                          , th [] [ text "Document" ]
                          , th [] [ text "Notes" ]
                          ]
                      ]
                  , tbody []
                      (List.map documentRow model.documents)
                  ]
              ]
          , case model.error of
              Just errorMsg ->
                  div [] [ text ("Error: " ++ errorMsg) ]

              Nothing ->
                  text ""  -- Use text "" to represent no content
          ]


documentRow : Document -> Html Msg
documentRow doc =
    tr []
        [ td [] [ text doc.id ]
        , td [] [ text  (Maybe.withDefault "No Date" doc.date)  ]
        , td [] [ a [ href ("api/couchdb/documents/" ++ doc.id) , class "document-link"] [ text "Document" ] ]
        , td [] [ text (Maybe.withDefault "No Notes" doc.notes) ]
        ]


-- HTTP REQUEST

fetchDocuments : Cmd Msg
fetchDocuments =
    Http.get
        { url = "http://localhost:4000/api/couchdb/document"
        , expect = Http.expectJson DocumentsFetched (Decode.field "documents" (Decode.list documentDecoder))
        }


documentDecoder : Decode.Decoder Document
documentDecoder =
   Decode.map3 Document
        (Decode.field "_id" Decode.string)
        (Decode.maybe (Decode.field "Date" Decode.string))
        (Decode.maybe (Decode.field "Notes" Decode.string))


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
    Browser.element
        { init = \flags -> init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }