module DownloadingData exposing (..)

import Browser exposing (element)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode



-- MODEL


type alias Document =
    { id : Maybe String
    , date : Maybe String
    , notes : Maybe String
    , site : Maybe String
    , province : Maybe String
    }


type alias Model =
    { documents : List Document
    , filteredDocuments : List Document
    , searchText : String
    , error : Maybe String
    , currentPage : Int
    , itemsPerPage : Int
    }


init : ( Model, Cmd Msg )
init =
    ( { documents = []
      , filteredDocuments = []
      , searchText = ""
      , error = Nothing
      , currentPage = 1
      , itemsPerPage = 11
      }
    , fetchDocuments ""
      -- Fetch all documents initially
    )



-- UPDATE


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
            ( model, fetchDocuments model.searchText )

        DocumentsFetched (Ok docs) ->
            ( { model | documents = docs, filteredDocuments = docs, error = Nothing }, Cmd.none )

        DocumentsFetched (Err err) ->
            ( { model | error = Just (errorToString err) }, Cmd.none )

        SearchTextChanged text ->
            let
                filteredDocs =
                    if String.isEmpty text then
                        model.documents

                    else
                        List.filter (\doc -> String.contains (String.toLower text) (Maybe.withDefault "" doc.notes)) model.documents
            in
            ( { model | searchText = text, filteredDocuments = filteredDocs }, Cmd.none )

        ClearSearch ->
            ( { model | searchText = "", filteredDocuments = model.documents }, Cmd.none )

        NextPage ->
            let
                totalPages =
                    (List.length model.filteredDocuments + model.itemsPerPage - 1) // model.itemsPerPage
            in
            ( { model | currentPage = Basics.min (model.currentPage + 1) totalPages }, Cmd.none )

        PrevPage ->
            ( { model | currentPage = Basics.max (model.currentPage - 1) 1 }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    let
        start =
            (model.currentPage - 1) * model.itemsPerPage

        paginatedDocuments =
            List.drop start model.filteredDocuments
                |> List.take model.itemsPerPage
    in
    div [ class "flex flex-col min-h-screen" ]
        [ Html.node "link"
            [ attribute "rel" "stylesheet"
            , attribute "href" "styles.css"
            ]
            []
        , nav [ class "bg-neutral-100 shadow-sm mb-5", Html.Attributes.style "background-color" "rgb(17, 71, 104)" ]
            [ div [ class "container mx-auto px-4 py-3 flex items-center justify-between" ]
                [ div [ class "brand-container" ]
                    [ img [ Html.Attributes.src "images/images.png", Html.Attributes.alt "Logo", class "logo" ] []
                    , div [ class "brand-title" ] [ text "CBC" ]
                    ]
                , ul [ class "nav-items" ]
                    [ li [] [ a [ href "/home", class "nav-link" ] [ text "HOME" ] ]
                    , li [ class "group" ]
                        [ a [ href "#", class "nav-link" ] [ text "DATA" ]
                        , ul [ class "dropdown" ]
                            [ li [] [ a [ href "/downloading", class "dropdown-link" ] [ text "Get Data" ] ]
                            , li [] [ a [ href "/publish", class "dropdown-link" ] [ text "Publish Data" ] ]
                            ]
                        ]
                    , li [ class "group" ]
                        [ a [ href "#", class "nav-link" ] [ text "SURVEYS" ]
                        , ul [ class "dropdown" ]
                            [ li [] [ a [ href "/map", class "dropdown-link" ] [ text "Map" ] ]
                            , li [] [ a [ href "/surveys", class "dropdown-link" ] [ text "Survey Collection" ] ]
                            ]
                        ]
                    , li [] [ a [ href "/contact", class "nav-link" ] [ text "CONTACT" ] ]
                    ]
                ]
            ]
        , div [ class "search-bar container mx-auto flex-grow items-center mb-4 w-full px-3 py-2 border border-neutral-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-neutral-400" ]
            [ input
                [ class "search-input"
                , type_ "text"
                , placeholder "Search by text"
                , value model.searchText
                , onInput SearchTextChanged
                ]
                []
            , button [ class "btn mb-4 bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick FetchDocuments ] [ text "Search" ]
            , button [ class "clear-btn bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick ClearSearch ] [ text "X" ]
            ]
        , div [ class "grid document-card grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 container mx-auto px-4 py-8 flex-grow" ]
            (List.map documentCard paginatedDocuments)
        , div [ class "pagination mt-4 flex justify-between container mx-auto px-4" ]
            [ button [ onClick PrevPage, disabled (model.currentPage == 1), class "btn" ] [ text "Previous" ]
            , span [] [ text ("Page " ++ String.fromInt model.currentPage) ]
            , button [ onClick NextPage, disabled ((model.currentPage * model.itemsPerPage) >= List.length model.filteredDocuments), class "btn" ] [ text "Next" ]
            ]
        , case model.error of
            Just errorMsg ->
                div [] [ text ("Error: " ++ errorMsg) ]

            Nothing ->
                text ""
        , footer [ class "footer" ]
            [ div [ class "container mx-auto" ]
                [ div [ class "footer-content" ]
                    [ div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "CBC" ]
                        , p [ class "footer-text" ] [ text "Enhancing access to biological control data" ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Quick Links" ]
                        , ul []
                            [ li [] [ a [ href "#", class "footer-link" ] [ text "Privacy Policy" ] ]
                            , li [] [ a [ href "#", class "footer-link" ] [ text "Terms of Service" ] ]
                            , li [] [ a [ href "/contact", class "footer-link" ] [ text "Contact Us" ] ]
                            ]
                        ]
                    , div [ class "footer-section" ]
                        [ h3 [ class "footer-title" ] [ text "Connect With Us" ]
                        , div [ class "social-icons" ]
                            [ a [ href "#", class "fa fa-facebook" ] []
                            , a [ href "#", class "fa fa-twitter" ] []
                            , a [ href "#", class "fa fa-instagram" ] []
                            , a [ href "#", class "fa fa-linkedin" ] []
                            ]
                        ]
                    ]
                ]
            , div [ class "footer-credits" ]
                [ p [] [ text "© 2025 Center for Biological Control. All rights reserved." ] ]
            ]
        ]



-- RENDER DOCUMENT CARD


documentCard : Document -> Html Msg
documentCard doc =
    div [ class "border rounded shadow p-4 bg-white flex-grow" ]
        [ div [ class "flex items-center justify-between mb-4" ]
            [ h2 [ class "text-lg font-semibold" ] [ text ("Collection ID: #" ++ Maybe.withDefault "Unknown" doc.id) ]
            , span [ class "badge active" ] [ text "Active" ]
            ]
        , div [ class "mb-2" ]
            [ text ("Created: " ++ Maybe.withDefault "No Date" doc.date) ]
        , div [ class "mb-2" ]
            [ text ("Location: " ++ Maybe.withDefault "No Site" doc.site) ]
        , div [ class "mb-2" ]
            [ text ("Province: " ++ Maybe.withDefault "No Province" doc.province) ]
        , div [ class "mb-4" ]
            [ text ("Notes: " ++ Maybe.withDefault "No Notes" doc.notes) ]
        , a [ href ("api/Mongodb/documents/" ++ Maybe.withDefault "Unknown" doc.id), class "btn btn-primary" ] [ text "View Document" ]
        ]



-- HTTP REQUEST


fetchDocuments : String -> Cmd Msg
fetchDocuments searchString =
    let
        url =
            if String.isEmpty searchString then
                "http://localhost:4000/api/Mongodb/document"
                -- Fetch all documents initially

            else
                "http://localhost:4000/api/Mongodb/document/search?search=" ++ searchString

        -- Fetch documents based on search
    in
    Http.get
        { url = url
        , expect = Http.expectJson DocumentsFetched (Decode.field "documents" (Decode.list documentDecoder))
        }


documentDecoder : Decode.Decoder Document
documentDecoder =
    Decode.map5 Document
        (Decode.maybe (Decode.field "_id" Decode.string))
        (Decode.maybe (Decode.field "Date" Decode.string))
        (Decode.maybe (Decode.field "Notes" Decode.string))
        (Decode.maybe (Decode.field "Site" Decode.string))
        (Decode.maybe (Decode.field "Province" Decode.string))


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
        { init = \_ -> init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
