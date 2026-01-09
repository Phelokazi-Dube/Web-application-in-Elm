port module UploadingData exposing (..)

import Browser
import Browser.Navigation exposing (..)
import File exposing (File)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick, onSubmit)
import Http
import Regex
import Json.Decode as D
import Json.Encode as E
import Html.Keyed exposing (..)
port receiveLocationPort : (String -> msg) -> Sub msg
port pickLocationPort : () -> Cmd msg




-- FLAGS

type alias Flags =
    { baseUrl : String
    , csrfToken : String
    }


-- PROVINCES

type Province
    = None
    | EasternCape
    | Gauteng
    | WesternCape
    | KwaZuluNatal
    | FreeState
    | Mpumalanga
    | Limpopo
    | NorthWest
    | NorthernCape


-- WEEDS

type alias WeedEntry =
    { name : String
    , present : Bool
    , absent : Bool
    }

type alias OtherWeed =
    { name : String
    , present : Bool
    , absent : Bool
    }


-- MODEL

type alias Model =
    { surveyType : String
    , location : String
    , controlAgent : String
    , weather : String
    , water : String
    , photos : List File
    , publications : List File
    , province : Province
    , programme : String
    , site : String
    , date : String
    , notes : String
    , csrf_token : String
    , weeds : List WeedEntry
    , otherWeeds : List OtherWeed
    , baseUrl : String
    }


-- INITIAL MODEL

init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { surveyType = ""
      , location = ""
      , controlAgent = ""
      , weather = ""
      , water = ""
      , photos = []
      , publications = []
      , province = None
      , programme = ""
      , site = ""
      , date = ""
      , notes = ""
      , csrf_token = flags.csrfToken
      , baseUrl = flags.baseUrl
      , weeds = []
      , otherWeeds = []
      }
    , Cmd.none
    )


-- MESSAGES

type Msg
    = NoOp
    | SurveyTypeChanged String
    | LocationChanged String
    | ControlAgentChanged String
    | WeatherChanged String
    | WaterChanged String
    | SiteChanged String
    | DateChanged String
    | NotesChanged String
    | ProvinceSelected Province
    | ProgrammeChanged String
    | FilesSelected (List File)
    | RemovePhoto Int
    | WeedPresentChanged Int Bool
    | WeedAbsentChanged Int Bool
    | AddOtherWeed
    | RemoveOtherWeed Int
    | UpdateOtherWeedName Int String
    | ToggleOtherWeedPresent Int
    | ToggleOtherWeedAbsent Int
    | SaveObservation
    | UploadResponse (Result Http.Error String)
    | LocationPicked String
    | StartPicking
    | PublicationsSelected (List File)
    | RemovePublication Int



-- UPDATE

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp -> ( model, Cmd.none )
        LocationPicked locStr -> ( { model | location = locStr }, Cmd.none )
        StartPicking -> ( model, pickLocationPort () )
        SurveyTypeChanged v -> ( { model | surveyType = v }, Cmd.none )
        LocationChanged v -> ( { model | location = v }, Cmd.none )
        ControlAgentChanged v -> ( { model | controlAgent = v }, Cmd.none )
        WeatherChanged v -> ( { model | weather = v }, Cmd.none )
        WaterChanged v -> ( { model | water = v }, Cmd.none )
        SiteChanged v -> ( { model | site = v }, Cmd.none )
        DateChanged v -> ( { model | date = v }, Cmd.none )
        NotesChanged v -> ( { model | notes = v }, Cmd.none )
        ProvinceSelected p -> ( { model | province = p }, Cmd.none )
        ProgrammeChanged prog ->
            let
                weedsForProgramme =
                    case prog of
                        "Agricultural Research Programme" ->
                            [ { name = "Citrus pests", present = False, absent = False }
                            , { name = "Apple pests", present = False, absent = False }
                            , { name = "Pear pests", present = False, absent = False }
                            , { name = "Cabbage pests", present = False, absent = False }
                            , { name = "Potato pests", present = False, absent = False }
                            , { name = "Litchi pests", present = False, absent = False }
                            , { name = "Macadamia pests", present = False, absent = False }
                            , { name = "Pecan pests", present = False, absent = False }
                            ]

                        "Cactaceae Programme" ->
                            [ { name = "Opuntia spp.", present = False, absent = False }
                            , { name = "Cylindropuntia spp.", present = False, absent = False }
                            , { name = "Cereus spp.", present = False, absent = False }
                            ]

                        "Northern Temperate Weeds" ->
                            [ { name = "Acer spp.", present = False, absent = False }
                            , { name = "Cotoneaster spp.", present = False, absent = False }
                            , { name = "Fraxinus spp.", present = False, absent = False }
                            , { name = "Gleditsia triacanthos", present = False, absent = False }
                            , { name = "Populus alba", present = False, absent = False }
                            , { name = "Populus canescens", present = False, absent = False }
                            , { name = "Pyracantha angustifolia", present = False, absent = False }
                            , { name = "Robinia pseudoacacia", present = False, absent = False }
                            , { name = "Rosa rubiginosa", present = False, absent = False }
                            , { name = "Salix fragilis", present = False, absent = False }
                            , { name = "Salix babylonica", present = False, absent = False }
                            ]

                        _ -> []
            in
            ( { model | programme = prog, weeds = weedsForProgramme }, Cmd.none )

        FilesSelected newFiles -> ( { model | photos = model.photos ++ newFiles }, Cmd.none )

        RemovePhoto idx ->
            ( { model | photos =
                model.photos
                    |> List.indexedMap Tuple.pair
                    |> List.filter (\(i, _) -> i /= idx)
                    |> List.map Tuple.second
              }
            , Cmd.none
            )

        PublicationsSelected files ->
            let
                pdfsOnly = List.filter isPdf files
            in
            ( { model | publications = model.publications ++ pdfsOnly }, Cmd.none )

        RemovePublication idx ->
            ( { model
                | publications =
                    model.publications
                        |> List.indexedMap Tuple.pair
                        |> List.filter (\(i, _) -> i /= idx)
                        |> List.map Tuple.second
            }
            , Cmd.none
            )

        WeedPresentChanged idx present ->
            let
                updateWeed i w =
                    if i == idx then { w | present = present, absent = if present then False else w.absent } else w
            in
            ( { model | weeds = List.indexedMap updateWeed model.weeds }, Cmd.none )

        WeedAbsentChanged idx absent ->
            let
                updateWeed i w =
                    if i == idx then { w | absent = absent, present = if absent then False else w.present } else w
            in
            ( { model | weeds = List.indexedMap updateWeed model.weeds }, Cmd.none )

        AddOtherWeed ->
            let newOther = { name = "", present = False, absent = False }
            in ( { model | otherWeeds = model.otherWeeds ++ [ newOther ] }, Cmd.none )

        RemoveOtherWeed idx ->
            ( { model | otherWeeds = List.indexedMap Tuple.pair model.otherWeeds
                                |> List.filter (\(i, _) -> i /= idx)
                                |> List.map Tuple.second }
            , Cmd.none
            )

        UpdateOtherWeedName idx name ->
            let updateOther i w = if i == idx then { w | name = name } else w
            in ( { model | otherWeeds = List.indexedMap updateOther model.otherWeeds }, Cmd.none )

        ToggleOtherWeedPresent idx ->
            let updateOther i w =
                    if i == idx then { w | present = not w.present, absent = if not w.present then False else w.absent } else w
            in ( { model | otherWeeds = List.indexedMap updateOther model.otherWeeds }, Cmd.none )

        ToggleOtherWeedAbsent idx ->
            let updateOther i w =
                    if i == idx then { w | absent = not w.absent, present = if not w.absent then False else w.present } else w
            in ( { model | otherWeeds = List.indexedMap updateOther model.otherWeeds }, Cmd.none )

        SaveObservation ->
            if not (isValidDate model.date) then
                ( model, Cmd.none )
            else
                let
                    -- encode weeds and other weeds as JSON strings
                    weedsJson = encodeWeeds model.weeds
                    otherWeedsJson = encodeOtherWeeds model.otherWeeds
                    textParts =
                        [ Http.stringPart "surveyType" model.surveyType
                        , Http.stringPart "location" model.location
                        , Http.stringPart "controlAgent" model.controlAgent
                        , Http.stringPart "weather" model.weather
                        , Http.stringPart "water" model.water
                        , Http.stringPart "province" (provinceToString model.province)
                        , Http.stringPart "programme" model.programme
                        , Http.stringPart "site" model.site
                        , Http.stringPart "date" model.date
                        , Http.stringPart "notes" model.notes
                        , Http.stringPart "weeds" weedsJson
                        , Http.stringPart "otherWeeds" otherWeedsJson
                        , Http.stringPart "_csrf_token" model.csrf_token
                        ]

                    fileParts =
                        List.indexedMap (\i f -> Http.filePart ("photos[" ++ String.fromInt i ++ "]") f) model.photos

                    publicationParts =
                        List.indexedMap
                            (\i f -> Http.filePart ("publications[" ++ String.fromInt i ++ "]") f)
                            model.publications

                    request =
                        Http.post
                            { url = model.baseUrl ++ "/uploading"
                            , body = Http.multipartBody (textParts ++ fileParts ++ publicationParts)
                            , expect = Http.expectString UploadResponse
                            }
                in
                ( model, request )


        UploadResponse (Ok _) -> ( { model | photos = [], publications = [] }, Cmd.none )
        UploadResponse (Err _) -> ( model, Cmd.none )


-- PROVINCE DROPDOWN

provinceDropdown : Province -> Html Msg
provinceDropdown selectedProvince =
    let
        provinces =
            [ None, EasternCape, Gauteng, WesternCape, KwaZuluNatal, FreeState, Mpumalanga, Limpopo, NorthWest, NorthernCape ]
    in
    select
        [ name "province"
        , onInput (ProvinceSelected << stringToProvince)
        ]
        (List.map
            (\p ->
                option
                    [ value (provinceToString p)
                    , selected (p == selectedProvince)
                    ]
                    [ text (provinceToString p) ]
            )
            provinces
        )


provinceToString : Province -> String
provinceToString province =
    case province of
        None -> "Select a province"
        EasternCape -> "Eastern Cape"
        Gauteng -> "Gauteng"
        WesternCape -> "Western Cape"
        KwaZuluNatal -> "KwaZulu-Natal"
        FreeState -> "Free State"
        Mpumalanga -> "Mpumalanga"
        Limpopo -> "Limpopo"
        NorthWest -> "North West"
        NorthernCape -> "Northern Cape"


stringToProvince : String -> Province
stringToProvince str =
    case str of
        "Eastern Cape" -> EasternCape
        "Gauteng" -> Gauteng
        "Western Cape" -> WesternCape
        "KwaZulu-Natal" -> KwaZuluNatal
        "Free State" -> FreeState
        "Mpumalanga" -> Mpumalanga
        "Limpopo" -> Limpopo
        "North West" -> NorthWest
        "Northern Cape" -> NorthernCape
        _ -> None


-- FILES DECODER & VIEW

filesDecoder : D.Decoder (List File)
filesDecoder =
    D.at [ "target", "files" ] (D.list File.decoder)

isPdf : File -> Bool
isPdf file =
    String.endsWith ".pdf" (String.toLower (File.name file))

isValidDate : String -> Bool
isValidDate date =
    Regex.contains (Regex.fromString "^\\d{2}/\\d{2}/\\d{4}$" |> Maybe.withDefault Regex.never) date

encodeWeed : WeedEntry -> E.Value
encodeWeed weed =
    let
        fields =
            [ ("name", E.string weed.name) ]
                |> maybeAdd "present" weed.present
                |> maybeAdd "absent" weed.absent
    in
    E.object fields

encodeOtherWeed : OtherWeed -> E.Value
encodeOtherWeed weed =
    let
        fields =
            [ ("name", E.string weed.name) ]
                |> maybeAdd "present" weed.present
                |> maybeAdd "absent" weed.absent
    in
    E.object fields

maybeAdd : String -> Bool -> List (String, E.Value) -> List (String, E.Value)
maybeAdd key value list =
    if value then
        list ++ [ ( key, E.bool True ) ]
    else
        list

-- only include weeds that have at least one box ticked
encodeWeeds : List WeedEntry -> String
encodeWeeds weeds =
    weeds
        |> List.filter (\w -> w.present || w.absent)
        |> (\filtered -> E.encode 0 (E.list encodeWeed filtered))

encodeOtherWeeds : List OtherWeed -> String
encodeOtherWeeds weeds =
    weeds
        |> List.filter (\w -> w.present || w.absent)
        |> (\filtered -> E.encode 0 (E.list encodeOtherWeed filtered))

viewPhotos : Model -> Html Msg
viewPhotos model =
    div [ class "field photos" ]
        ([ label [] [ text "Photos" ]
         , input
            [ type_ "file"
            , name "photos"
            , accept "image/*"
            , multiple True
            , Html.Events.on "change" (D.map FilesSelected filesDecoder)
            ]
            []
        ]
            ++ (if List.isEmpty model.photos then []
                else
                    [ div [ class "photo-preview-list" ]
                        (List.indexedMap
                            (\i file ->
                                div [ class "photo-item" ]
                                    [ text (File.name file)
                                    , button [ type_ "button", onClick (RemovePhoto i) ] [ text "❌ Remove" ]
                                    ]
                            )
                            model.photos
                        )
                    ]
               )
        )

viewPublications : Model -> Html Msg
viewPublications model =
    div [ class "field publications" ]
        [ label [] [ text "Publications (PDF only)" ]
        , input
            [ type_ "file"
            , multiple True
            , accept "application/pdf"
            , Html.Events.on "change" (D.map PublicationsSelected filesDecoder)
            ]
            []
        , div [ class "publication-list" ]
            (List.indexedMap
                (\i f ->
                    div []
                        [ text (File.name f)
                        , button
                            [ type_ "button"
                            , onClick (RemovePublication i)
                            ]
                            [ text "❌ Remove" ]
                        ]
                )
                model.publications
            )
        ]

-- VIEW OTHER WEEDS

viewOtherWeeds : Model -> Html Msg
viewOtherWeeds model =
    div [ class "other-weeds" ]
        (List.concat
            [ List.indexedMap
                (\idx weed ->
                    div [ class "field other-weed" ]
                        [ input
                            [ type_ "text"
                            , placeholder "Other species name"
                            , value weed.name
                            , onInput (UpdateOtherWeedName idx)
                            ]
                            []
                        , label [] [ input [ type_ "checkbox", checked weed.present, onClick (ToggleOtherWeedPresent idx) ] [], text " Present" ]
                        , label [] [ input [ type_ "checkbox", checked weed.absent, onClick (ToggleOtherWeedAbsent idx) ] [], text " Absent" ]
                        , button [ type_ "button", onClick (RemoveOtherWeed idx) ] [ text "x" ]
                        ]
                )
                model.otherWeeds
            , [ button [ type_ "button", onClick AddOtherWeed ] [ text "+ Add another species" ] ]
            ]
        )

subscriptions : Model -> Sub Msg
subscriptions model =
    receiveLocationPort LocationPicked



-- VIEW

view : Model -> Html Msg
view model =
    div [ class "uploading-container" ]
        [ div [ class "header" ] [ div [ class "navtab" ] [] ]
        , div [ id "wrapper", class "container clear" ]
            [ div [ id "pageheader", class "column span-26" ]
                [ h2 [ class "add-observation" ] [ text "Add an Observation" ] ]
            , div [ class "column span-24" ]
                [ Html.form [ onSubmit SaveObservation, method "post", class "form-group", enctype "multipart/form-data" ]
                    (  [ div [ class "field" ]
                                [ label [] [ text "Survey type" ]
                                , input [ type_ "text", name "surveyType", placeholder "Post-release or Pre-release or Survey", value model.surveyType, onInput SurveyTypeChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Location" ]
                                , input [ type_ "text", name "location", placeholder "Latitude, Longitude", value model.location, onInput LocationChanged ] []
                                ]
                        , button
                            [ type_ "button"
                            , onClick StartPicking
                            , class "map-button"
                            ]
                            [ text "📍 Pick on Map" ]
                        , div [ class "field" ]
                                [ label [] [ text "Control agent" ]
                                , input [ type_ "text", name "controlAgent", value model.controlAgent, onInput ControlAgentChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Weather" ]
                                , input [ type_ "text", name "weather", value model.weather, onInput WeatherChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Water" ]
                                , textarea [ name "water", placeholder "e.g., River, clear water, temp 18°C", onInput WaterChanged ] [ text model.water ]
                                ]
                        , viewPhotos model
                        , viewPublications model
                        , div [ class "field" ]
                                [ label [] [ text "Province" ]
                                , provinceDropdown model.province
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Programme" ]
                                , input [ type_ "text", name "programme", placeholder "e.g., Aquatic Weeds Programme, or General Member", value model.programme, onInput ProgrammeChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Site" ]
                                , input [ type_ "text", name "site", placeholder "Site name", value model.site, onInput SiteChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Date" ]
                                , input [ type_ "text", name "date", placeholder "MM-DD-YYYY", value model.date, onInput DateChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Notes" ]
                                , textarea [ name "notes", onInput NotesChanged ] [ text model.notes ]
                                ]
                        , input [ type_ "hidden", name "_csrf_token", value model.csrf_token ] []
                        ]
                            ++ (List.indexedMap
                                (\i weed ->
                                    div [ class "weed-entry" ]
                                        [ text weed.name
                                        , input [ type_ "checkbox", checked weed.present, onClick (WeedPresentChanged i (not weed.present)) ] []
                                        , text " Present "
                                        , input [ type_ "checkbox", checked weed.absent, onClick (WeedAbsentChanged i (not weed.absent)) ] []
                                        , text " Absent "
                                        ]
                                )
                                model.weeds
                            )
                        ++ [ viewOtherWeeds model ]
                        ++ [ div [ class "uploading-buttons" ]
                                [ button [ type_ "submit", class "save-observation-btn" ] [ text "Save Observation" ]
                                , button [ type_ "button", class "cancel-observation-btn", onClick NoOp ] [ text "Cancel" ]
                                ]
                           ]
                    )
                ]
            ]
        ]


-- MAIN

main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
