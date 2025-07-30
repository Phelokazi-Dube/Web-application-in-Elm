module UploadingData exposing (..)

import Browser
import Browser.Navigation exposing (load)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import Json.Decode as Decode exposing (Decoder)
import Task




type alias Flags =
    { baseUrl : String
    , csrfToken : String
    }

-- Model


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


type alias Model =
    { surveyType : String
    , location : String
    , controlAgent : String
    , targetWeedName : String
    , targetWeedRank : String
    , targetWeedId : String
    , targetWeedTaxonName : String
    , weather : String
    , water : String
    , photos : String
    , province : Province
    , programme : String
    , sitename : String
    , date : String
    , noLeaves : Maybe Int
    , noStems : Maybe Int
    , noFlowers : Maybe Int
    , noCapsules : Maybe Int
    , maxHeight : Maybe Int
    , noRamets : Maybe Int
    , sizeOfInf : String
    , percentCover : Maybe Float
    , description : String
    , csrf_token : String
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { surveyType = ""
      , location = ""
      , controlAgent = ""
      , targetWeedName = ""
      , targetWeedRank = ""
      , targetWeedId = ""
      , targetWeedTaxonName = ""
      , weather = ""
      , water = ""
      , photos = ""
      , province = None
      , programme = ""
      , sitename = ""
      , date = ""
      , noLeaves = Nothing
      , noStems = Nothing
      , noFlowers = Nothing
      , noCapsules = Nothing
      , maxHeight = Nothing
      , noRamets = Nothing
      , sizeOfInf = ""
      , percentCover = Nothing
      , description = ""
      , csrf_token = flags.csrfToken
      }
    , Cmd.none
    )



-- Messages


type Msg
    = NoOp
    | ProvinceSelected Province
    | FileUploaded String



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        ProvinceSelected selectedProvince ->
            ( { model | province = selectedProvince }, Cmd.none )

        FileUploaded filePath ->
            ( { model | photos = filePath }, Cmd.none )



-- Helper function to generate radio buttons for provinces


provinceRadioButtons : Province -> Html Msg
provinceRadioButtons selectedProvince =
    div [ class "province-buttons" ]
        [ label [ class "radio-label" ]
            [ text "Eastern Cape"
            , input [ type_ "radio", name "province", value "Eastern Cape", checked (selectedProvince == EasternCape), onClick (ProvinceSelected EasternCape) ] []
            ]
        , label [ class "radio-label" ]
            [ text "Gauteng"
            , input [ type_ "radio", name "province", value "Gauteng", checked (selectedProvince == Gauteng), onClick (ProvinceSelected Gauteng) ] []
            ]
        , label [ class "radio-label" ]
            [ text "Western Cape"
            , input [ type_ "radio", name "province", value "Western Cape", checked (selectedProvince == WesternCape), onClick (ProvinceSelected WesternCape) ] []
            ]
        , label [ class "radio-label" ]
            [ text "North West"
            , input [ type_ "radio", name "province", value "North West", checked (selectedProvince == NorthWest), onClick (ProvinceSelected NorthWest) ] []
            ]
        , label [ class "radio-label" ]
            [ text "Northern Cape"
            , input [ type_ "radio", name "province", value "Northern Cape", checked (selectedProvince == NorthernCape), onClick (ProvinceSelected NorthernCape) ] []
            ]
        , label [ class "radio-label" ]
            [ text "KwaZulu-Natal"
            , input [ type_ "radio", name "province", value "KwaZulu Natal", checked (selectedProvince == KwaZuluNatal), onClick (ProvinceSelected KwaZuluNatal) ] []
            ]
        , label [ class "radio-label" ]
            [ text "Limpopo"
            , input [ type_ "radio", name "province", value "Limpopo", checked (selectedProvince == Limpopo), onClick (ProvinceSelected Limpopo) ] []
            ]
        , label [ class "radio-label" ]
            [ text "Mpumalanga"
            , input [ type_ "radio", name "province", value "Mpumalanga", checked (selectedProvince == Mpumalanga), onClick (ProvinceSelected Mpumalanga) ] []
            ]
        , label [ class "radio-label" ]
            [ text "Free State"
            , input [ type_ "radio", name "province", value "Free State", checked (selectedProvince == FreeState), onClick (ProvinceSelected FreeState) ] []
            ]
        ]



-- View


view : Model -> Html Msg
view model =
    div [ class "uploading-container" ]
        [ -- Header
          div [ class "header" ]
            [ div [ class "navtab" ] []
            ]
        , div [ id "wrapper", class "container clear" ]
            [ div [ id "pageheader", class "column span-26" ]
                [ h2 [ class "add-observation" ] [ text "Add an Observation" ]
                ]
            , div [ class "column span-24" ]
                [ Html.form [ Html.Attributes.method "post", Html.Attributes.class "form-group", Html.Attributes.enctype "multipart/form-data" ]
                    [ div [ class "field" ]
                        [ label [] [ text "Survey type" ]
                        , input [ type_ "text", id "surveyType", name "surveyType", placeholder "Post-release or pre-release or survey", value model.surveyType ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Location" ]
                        , input [ type_ "text", id "location", name "location", placeholder "Latitude(41.27872259999999), Longitude( -72.5571845909)", value model.location ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Control agent" ]
                        , input [ type_ "text", id "controlAgent", name "controlAgent", value model.controlAgent ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Target weed name" ]
                        , input [ type_ "text", id "targetWeedName", name "targetWeedName", placeholder "", value model.targetWeedName ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Target weed taxon rank" ]
                        , input [ type_ "text", id "targetWeedRank", name "targetWeedRank", placeholder "", value model.targetWeedRank ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Target weed taxon id" ]
                        , input [ type_ "text", id "targetWeedId", name "targetWeedId", placeholder "", value model.targetWeedId ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Target weed taxon name" ]
                        , input [ type_ "text", id "targetWeedTaxonName", name "targetWeedTaxonName", placeholder "", value model.targetWeedTaxonName ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Weather" ]
                        , input [ type_ "text", id "weather", name "weather", placeholder "", value model.weather ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Photos" ]
                        , input [ type_ "file", id "photos[]", name "photos[]", multiple True ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Water" ]
                        , textarea [ id "water", name "water", placeholder "e.g., River, clear water, temp 18°C"] [ text model.water ]
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Province" ]
                        , provinceRadioButtons model.province
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Programme" ]
                        , input [ type_ "text", id "programme", name "programme", placeholder "Aquatic Weeds Programme", value model.programme ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Sitename" ]
                        , input [ type_ "text", id "sitename", name "sitename", placeholder "Durban Botanical Gardens", value model.sitename ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Date" ]
                        , input [ type_ "text", id "date", name "date", placeholder "MM-DD-YYYY", value model.date ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "No. leaves" ]
                        , input [ type_ "text", id "noLeaves", name "noLeaves", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromInt model.noLeaves)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "No. stems" ]
                        , input [ type_ "text", id "noStems", name "noStems", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromInt model.noStems)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "No. flowers" ]
                        , input [ type_ "text", id "noFlowers", name "noFlowers", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromInt model.noFlowers)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "No. capsules" ]
                        , input [ type_ "text", id "noCapsules", name "noCapsules", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromInt model.noCapsules)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Max height" ]
                        , input [ type_ "text", id "maxHeight", name "maxHeight", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromInt model.maxHeight)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "No. ramets" ]
                        , input [ type_ "text", id "noRamets", name "noRamets", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromInt model.noRamets)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Size of inf." ]
                        , input [ type_ "text", id "sizeOfInf", name "sizeOfInf", placeholder "", value model.sizeOfInf ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "% Cover" ]
                        , input [ type_ "text", id "percentCover", name "percentCover", placeholder "", value (Maybe.withDefault "" (Maybe.map String.fromFloat model.percentCover)) ] []
                        ]
                    , div [ class "field" ]
                        [ label [] [ text "Description" ]
                        , textarea [ id "description", name "description" ] [ text model.description ]
                        ]
                    , input [ type_ "hidden", name "_csrf_token", value model.csrf_token ] []
                    , div [ class "uploading-buttons" ]
                        [ button [ type_ "submit", class "save-observation-btn" ] [ text "Save Observation" ]
                        , button [ type_ "button", class "cancel-observation-btn", onClick NoOp ] [ text "Cancel" ]
                        ]
                    ]
                ]
            ]
        ]


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
