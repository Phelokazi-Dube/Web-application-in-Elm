module UploadingData exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick, on, onSubmit)
import File.Select as Select
import File exposing (File)
import Html.Keyed exposing (..)


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
    , photos : List String
    , province : Province
    , programme : String
    , site : String
    , date : String
    , notes : String
    , csrf_token : String
    , weeds : List WeedEntry
    , otherWeeds : List OtherWeed
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
      , province = None
      , programme = ""
      , site = ""
      , date = ""
      , notes = ""
      , csrf_token = flags.csrfToken
      , weeds = []
      , otherWeeds = []
      }
    , Cmd.none
    )


-- MESSAGES

type Msg
    = NoOp
    | ProvinceSelected Province
    | FilesSelected (List String)
    | RemovePhoto Int
    | ProgrammeChanged String
    | WeedPresentChanged Int Bool
    | WeedAbsentChanged Int Bool
    | AddOtherWeed
    | RemoveOtherWeed Int
    | UpdateOtherWeedName Int String
    | ToggleOtherWeedPresent Int
    | ToggleOtherWeedAbsent Int


-- UPDATE

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ProvinceSelected p ->
            ( { model | province = p }, Cmd.none )

        FilesSelected newFiles ->

            ( { model | photos = model.photos ++ newFiles }, Cmd.none )

        RemovePhoto idx ->

            ( { model | photos = List.indexedMap Tuple.pair model.photos

                |> List.filter (\(i, _) -> i /= idx)
                |> List.map Tuple.second

              }
            , Cmd.none
            )

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

                        _ ->
                            []
            in
            ( { model | programme = prog, weeds = weedsForProgramme }, Cmd.none )

        WeedPresentChanged idx present ->
            let
                updateWeed i w =
                    if i == idx then
                        { w | present = present, absent = if present then False else w.absent }
                    else
                        w
            in
            ( { model | weeds = List.indexedMap updateWeed model.weeds }, Cmd.none )

        WeedAbsentChanged idx absent ->
            let
                updateWeed i w =
                    if i == idx then
                        { w | absent = absent, present = if absent then False else w.present }
                    else
                        w
            in
            ( { model | weeds = List.indexedMap updateWeed model.weeds }, Cmd.none )

        AddOtherWeed ->
            let
                newOther = { name = "", present = False, absent = False }
            in
            ( { model | otherWeeds = model.otherWeeds ++ [ newOther ] }, Cmd.none )

        RemoveOtherWeed idx ->
            ( { model | otherWeeds = List.indexedMap Tuple.pair model.otherWeeds
                                |> List.filter (\(i, _) -> i /= idx)
                                |> List.map Tuple.second
              }
            , Cmd.none
            )

        UpdateOtherWeedName idx name ->
            let
                updateOther i w =
                    if i == idx then
                        { w | name = name }
                    else
                        w
            in
            ( { model | otherWeeds = List.indexedMap updateOther model.otherWeeds }, Cmd.none )

        ToggleOtherWeedPresent idx ->
            let
                updateOther i w =
                    if i == idx then
                        { w | present = not w.present, absent = if not w.present then False else w.absent }
                    else
                        w
            in
            ( { model | otherWeeds = List.indexedMap updateOther model.otherWeeds }, Cmd.none )

        ToggleOtherWeedAbsent idx ->
            let
                updateOther i w =
                    if i == idx then
                        { w | absent = not w.absent, present = if not w.absent then False else w.present }
                    else
                        w
            in
            ( { model | otherWeeds = List.indexedMap updateOther model.otherWeeds }, Cmd.none )


-- PROVINCE DROPDOWN

provinceDropdown : Province -> Html Msg
provinceDropdown selectedProvince =
    let
        provinces =
            [ ( None, "Select a province" )
            , ( EasternCape, "Eastern Cape" )
            , ( Gauteng, "Gauteng" )
            , ( WesternCape, "Western Cape" )
            , ( KwaZuluNatal, "KwaZulu-Natal" )
            , ( FreeState, "Free State" )
            , ( Mpumalanga, "Mpumalanga" )
            , ( Limpopo, "Limpopo" )
            , ( NorthWest, "North West" )
            , ( NorthernCape, "Northern Cape" )
            ]

        provinceToString province =
            case province of
                None -> ""
                EasternCape -> "Eastern Cape"
                Gauteng -> "Gauteng"
                WesternCape -> "Western Cape"
                KwaZuluNatal -> "KwaZulu-Natal"
                FreeState -> "Free State"
                Mpumalanga -> "Mpumalanga"
                Limpopo -> "Limpopo"
                NorthWest -> "North West"
                NorthernCape -> "Northern Cape"

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
    in
    select
        [ name "province"
        , onInput (\val -> ProvinceSelected (stringToProvince val))
        ]
        (List.map
            (\( province, labelText ) ->
                option
                    [ value (provinceToString province)
                    , selected (province == selectedProvince)
                    ]
                    [ text labelText ]
            )
            provinces
        )

viewPhotos : Model -> Html Msg
viewPhotos model =
    div [ class "field photos" ]
        ([ label [] [ text "Photos" ]
         , input
            [ type_ "file"
            , name "photos[]"
            , multiple True
            , onInput
                (\val ->
                    FilesSelected (String.split "," val)
                )
            ]
            []
        ]
            ++ (if List.isEmpty model.photos then
                    []
                else
                    [ div [ class "photo-preview-list" ]
                        (List.indexedMap
                            (\i file ->
                                let
                                    -- Remove the fake Windows path part
                                    cleanName =
                                        String.replace "C:\\fakepath\\" "" file
                                in
                                div [ class "photo-item" ]
                                    [ text cleanName
                                    , button
                                        [ type_ "button"
                                        , onClick (RemovePhoto i)
                                        ]
                                        [ text "❌ Remove" ]
                                    ]
                            )
                            model.photos
                        )
                    ]
               )
        )


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


-- VIEW

view : Model -> Html Msg
view model =
    div [ class "uploading-container" ]
        [ div [ class "header" ] [ div [ class "navtab" ] [] ]
        , div [ id "wrapper", class "container clear" ]
            [ div [ id "pageheader", class "column span-26" ]
                [ h2 [ class "add-observation" ] [ text "Add an Observation" ] ]
            , div [ class "column span-24" ]
                [ Html.form [ method "post", class "form-group", enctype "multipart/form-data" ]
                    (  [ div [ class "field" ]
                                [ label [] [ text "Survey type" ]
                                , input [ type_ "text", name "surveyType", placeholder "Post-release or pre-release or survey", value model.surveyType ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Location" ]
                                , input [ type_ "text", name "location", placeholder "Latitude, Longitude", value model.location ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Control agent" ]
                                , input [ type_ "text", name "controlAgent", value model.controlAgent ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Weather" ]
                                , input [ type_ "text", name "weather", value model.weather ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Water" ]
                                , textarea [ name "water" ] [ text model.water ]
                                ]
                        , viewPhotos model
                        , div [ class "field" ]
                                [ label [] [ text "Province" ]
                                , provinceDropdown model.province
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Programme" ]
                                , input [ type_ "text", name "programme", placeholder "Programme name", value model.programme, onInput ProgrammeChanged ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Site" ]
                                , input [ type_ "text", name "site", placeholder "Site name", value model.site ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Date" ]
                                , input [ type_ "text", name "date", placeholder "MM-DD-YYYY", value model.date ] []
                                ]
                        , div [ class "field" ]
                                [ label [] [ text "Notes" ]
                                , textarea [ name "notes" ] [ text model.notes ]
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
        , subscriptions = \_ -> Sub.none
        }
