module UploadingData exposing (..)

import Browser
import Html exposing (Html, form)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, on)
import Json.Decode as Decode exposing (Decoder)



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
    , noLeaves : Int  
    , noStems : Int
    , noFlowers : Int
    , noCapsules : Int
    , maxHeight : Int
    , noRamets : Int
    , sizeOfInf : String
    , percentCover : Float
    , description : String
    , csrf_token : String
    }

init : String -> ( Model, Cmd Msg )
init token =
    ( { surveyType = "Post-release or pre-release or survey"
      , location = "41.27872259999999, -72.5571845909"
      , controlAgent = "plant hopper (Megamelus scutellaris)"
      , targetWeedName = "salvinia (Salvinia molesta)"
      , targetWeedRank = "species"
      , targetWeedId = "12345"
      , targetWeedTaxonName = "Salvinia molesta"
      , weather = "13°C"
      , water = "the water body is a river at a temperature of 18.9°C"
      , photos = ""
      , province = None
      , programme = "African Boxthorn Programme"
      , sitename = "PMB Botanical Gardens"
      , date = "10/18/2019"
      , noLeaves = 114
      , noStems = 0
      , noFlowers = 0
      , noCapsules = 0
      , maxHeight = 136
      , noRamets = 21
      , sizeOfInf = "2x2m"
      , percentCover = 0.0
      , description = ""
      , csrf_token = token
      }
      , Cmd.none
    )

type Msg
    = NoOp
    | ProvinceSelected Province


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)
        ProvinceSelected selectedProvince ->
            ({ model | province = selectedProvince }, Cmd.none)
 

-- Helper function to generate radio buttons for provinces
provinceRadioButtons : Province -> Html Msg
provinceRadioButtons selectedProvince =
    div []
        [ label [] [ text "Eastern Cape"
                   , input [ type_ "radio", name "province", value "Eastern Cape", checked (selectedProvince == EasternCape), onClick (ProvinceSelected EasternCape) ] []
                   ]
        , label [] [ text "Gauteng"
                   , input [ type_ "radio", name "province", value "Gauteng", checked (selectedProvince == Gauteng), onClick (ProvinceSelected Gauteng) ] []
                   ]
        , label [] [ text "Western Cape"
                   , input [ type_ "radio", name "province", value "Western Cape", checked (selectedProvince == WesternCape), onClick (ProvinceSelected WesternCape) ] []
                   ]
        , label [] [ text "North West"
                   , input [ type_ "radio", name "province", value "North West", checked (selectedProvince == NorthWest), onClick (ProvinceSelected NorthWest) ] []
                   ]
        , label [] [ text "Nothern Cape"
                   , input [ type_ "radio", name "province", value "Northern Cape", checked (selectedProvince == NorthernCape), onClick (ProvinceSelected NorthernCape) ] []
                   ]
        , label [] [ text "KwaZulu-Natal"
                   , input [ type_ "radio", name "province", value "KwaZulu Natal", checked (selectedProvince == KwaZuluNatal), onClick (ProvinceSelected KwaZuluNatal) ] []
                   ]
        , label [] [ text "Limpopo"
                   , input [ type_ "radio", name "province", value "Limpopo", checked (selectedProvince == Limpopo), onClick (ProvinceSelected Limpopo) ] []
                   ]
        , label [] [ text "Mpumalanga"
                   , input [ type_ "radio", name "province", value "Mpumalanga", checked (selectedProvince == Mpumalanga), onClick (ProvinceSelected Mpumalanga) ] []
                   ]
        , label [] [ text "Free State"
                   , input [ type_ "radio", name "province", value "Free State", checked (selectedProvince == FreeState), onClick (ProvinceSelected FreeState) ] []
                   ]
        ]

view : Model -> Html Msg
view model =
    div []
        [ -- First div - Header
          div [ class "header" ]
              [ -- Navtab with logo
                div [ class "navtab" ]
                    [ a [ href "#", class "logo" ] [ text "CBC" ]
                    ]
                -- Search bar with clear button
              , div [ class "search" ]
                    [ input [ type_ "text", placeholder "Search..." ] []
                    , button [ class "clear-btn", onClick NoOp ] [ text "X" ]
                    ]
              ]
        -- Second div - Wrapper
    , div [ id "wrapper", class "container clear" ]
            [ -- Page header
            div [ id "pageheader", class "column span-26" ]
                [ h2 [] [ text "Add an Observation" ]
                ]
                -- Form
        , div [ class "column span-24" ]
            [ Html.form [ Html.Attributes.method "post", Html.Attributes.class "form-group", Html.Attributes.enctype "multipart/form-data" ]
        [ -- Survey type
          div [ class "field" ]
              [ label [] [ text "Survey type" ]
              , input [ type_ "text", id "surveyType", name "surveyType", value model.surveyType ] []
              ]

                -- Latitude and Longitude
                , div [ class "field" ]
                    [ label [] [ text "Location" ]
                    , input [ type_ "text", id "location", name "location", placeholder "Latitude, Longitude", value model.location ] []
                    ]

                -- Control agent
                , div [ class "field" ]
                    [ label [] [ text "Control agent" ]
                    , input [ type_ "text", id "controlAgent", name "controlAgent", value model.controlAgent ] []
                    ]

                -- Target weed
                , div [ class "field" ]
                    [ label [] [ text "Target weed name" ]
                    , input [ type_ "text", id "targetWeedName", name "targetWeedName", value model.targetWeedName ] []
                    ]

                -- Target weed taxon rank
                , div [ class "field" ]
                    [ label [] [ text "Target weed taxon rank" ]
                    , input [ type_ "text", id "targetWeedRank", name "targetWeedRank", value model.targetWeedRank ] []
                    ]

                -- Target weed taxon id
                , div [ class "field" ]
                    [ label [] [ text "Target weed taxon id" ]
                    , input [ type_ "text", id "targetWeedId", name "targetWeedId", value model.targetWeedId ] []
                    ]

                -- Target weed taxon name
                , div [ class "field" ]
                    [ label [] [ text "Target weed taxon name" ]
                    , input [ type_ "text", id "targetWeedTaxonName", name "targetWeedTaxonName", value model.targetWeedTaxonName ] []
                    ]

                -- Weather
                , div [ class "field" ]
                    [ label [] [ text "Weather" ]
                    , input [ type_ "text", id "weather", name "weather", value model.weather ] []
                    ]

                -- Photos
               , div [ class "field" ]
                    [ label [] [ text "Photos" ]
                    , input [ type_ "file", id "photos[]", name "photos[]", multiple True ] []
                    ]

                -- Water
                , div [ class "field" ]
                    [ label [] [ text "Water" ]
                    , textarea [ id "water", name "water" ] [ text model.water ]
                    ]

                -- Province
                , div [ class "field" ]
                    [ label [] [ text "Province" ]
                    , provinceRadioButtons model.province 
                    ]

                  -- Programme
                , div [ class "field" ]
                    [ label [] [ text "Programme" ]
                    , input [ type_ "text", id "programme", name "programme", value model.programme ] []
                    ]

                -- Sitename
                , div [ class "field" ]
                    [ label [] [ text "Sitename" ]
                    , input [ type_ "text", id "sitename", name "sitename", value model.sitename ] []
                    ]

                -- Date
                , div [ class "field" ]
                    [ label [] [ text "Date" ]
                    , input [ type_ "text", id "date", name "date", value model.date ] []
                    ]

                -- No. leaves
                , div [ class "field" ]
                    [ label [] [ text "No. leaves" ]
                    , input [ type_ "text", id "noLeaves", name "noLeaves", value (String.fromInt model.noLeaves) ] []
                    ]

                -- No. stems
                , div [ class "field" ]
                    [ label [] [ text "No. stems" ]
                    , input [ type_ "text", id "noStems", name "noStems", value (String.fromInt model.noStems) ] []
                    ]

                -- No. flowers
                , div [ class "field" ]
                    [ label [] [ text "No. flowers" ]
                    , input [ type_ "text", id "noFlowers", name "noFlowers", value (String.fromInt model.noFlowers) ] []
                    ]

                -- No. capsules
                , div [ class "field" ]
                    [ label [] [ text "No. capsules" ]
                    , input [ type_ "text", id "noCapsules", name "noCapsules", value (String.fromInt model.noCapsules) ] []
                    ]

                -- Max height
                , div [ class "field" ]
                    [ label [] [ text "Max height" ]
                    , input [ type_ "text", id "maxHeight", name "maxHeight", value (String.fromInt model.maxHeight) ] []
                    ]

                -- No. ramets
                , div [ class "field" ]
                    [ label [] [ text "No. ramets" ]
                    , input [ type_ "text", id "noRamets", name "noRamets", value (String.fromInt model.noRamets) ] []
                    ]

                -- Size of inf.
                , div [ class "field" ]
                    [ label [] [ text "Size of inf." ]
                    , input [ type_ "text", id "sizeOfInf", name "sizeOfInf", value model.sizeOfInf ] []
                    ]

                -- % Cover
                , div [ class "field" ]
                    [ label [] [ text "% Cover" ]
                    , input [ type_ "text", id "percentCover", name "percentCover", value (String.fromFloat model.percentCover) ] []
                    ]

                -- Description
                , div [ class "field" ]
                    [ label [] [ text "Description" ]
                    , textarea [ id "description", name "description" ] [ text model.description ]
                    ]

                -- CSRF token (hidden).  This will be expected by Phoenix to validate the request.
                , input [ type_ "hidden", name "_csrf_token", value model.csrf_token ] []

                -- Add more fields as needed
                -- Submit buttons
                , div []
                    [ button [ type_ "submit" ] [ text "Save Observation" ]
                    , button [ type_ "button" ] [ text "Cancel" ]
                    ]
                    ]
                ]
            ]   
        ]


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
