module DownloadingData exposing (..)

import Browser
import Html exposing (Html, div, nav, h2, p, br, b, a, input, button, ul, li, text, node)
import Html.Attributes exposing (class, type_, name, placeholder, href, style, attribute, value)
import Html.Events exposing (onClick, onMouseOver, onInput)
import Browser.Navigation exposing (load)
import Http
import Json.Decode as D

-- Model
type alias Model =
    { searchText : String
    , results : List String
    , status : Status
    }

type Status
    = WaitingForServer
    | ErrorHappenedOhNo
    | GettingUserInput

-- Init
init : Model
init =
    { searchText = ""
    , results = []
    , status = GettingUserInput
    }


-- Update
type Msg
    -- Define your message types here
    = ChangeSearchText String
    | AskServerForResults
    | ReceiveResults (Result Http.Error (List String))

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        ChangeSearchText newText ->
            ( { model | searchText = newText }, Cmd.none )

        AskServerForResults ->
            ( { model | status = WaitingForServer }
            , fetchResults model.searchText
            )

        ReceiveResults possibleResults ->
            case possibleResults of
                Ok newResults ->
                    ( { model | results = newResults, status = GettingUserInput }, Cmd.none )

                Err _ ->
                    ( { model | status = ErrorHappenedOhNo }, Cmd.none )

decodeResults : D.Decoder (List String)
decodeResults =
    D.list D.string

fetchResults : String -> Cmd Msg
fetchResults searchString =
    Http.get
        { url = "/api/documentIdsByText?search=" ++ searchString
        , expect = Http.expectJson ReceiveResults decodeResults
        }

subscriptions : Model -> Sub Msg
subscriptions model =
    -- Define your subscriptions here
    Sub.none


view : Model -> Html Msg
view model =
    div [ class "main" ]
        [ node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "/css/styling.css"
            ]
            []
        , nav
            [ class "navbar" ]
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
                            [ a [ href "/uploading" ] [ text "Get Data" ]
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
                            [ a [ href "#" ] [ text "Form" ]
                            ]
                        ]
                    ]
                , li []
                    [ a [ href "/contact" ] [ text "CONTACT" ]
                    ]
                ]
            ]
        , case model.status of
            GettingUserInput ->
                div [ class "search" ]
                    [ input
                        [ class "srch"
                        , type_ "search"
                        , placeholder "Type to search"
                        , value model.searchText
                        , onInput ChangeSearchText
                        ]
                        []
                    , button
                        [ class "btn"
                        , onClick AskServerForResults
                        ]
                        [ text "Search" ]
                    ]
            WaitingForServer ->
                div
                    [ ]
                    [ text ("Searching for '" ++ model.searchText ++ "', please wait…") ]
            ErrorHappenedOhNo ->
                div
                    [ ]
                    [ text <| "Oh no! An error occurred while searching for '" ++ model.searchText ++ "'."
                    , text "  Please contact the developer, who will be very sorry and will fix it ASAP."
                    ]
        , div
            [ class "body" ]
            ( List.map
                (\result ->
                    p
                        []
                        [ text "I found the result: "
                        , text result
                        ]
                )
                model.results
            )
            -- [  p []
            --     [ text "Welcome to the CBC Portal"
            --     , br [] []
            --     , text "You can download data from "
            --     , b [] [ a [ href "/api/couchdb/documents/:id", style "color" "black", style "text-decoration" "underline"] [ text "here" ] ]
            --     ]
            -- ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> (init, Cmd.none)
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
