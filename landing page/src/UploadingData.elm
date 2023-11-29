module UploadingData exposing (..)

import Browser
import Html exposing (Html, form)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)

-- ALL of this is stringly-typed data?  That's a recipe for disaster in future.
-- Please be sure that you use proper data types after you have a basic working version.
type alias Model =
    { surveyType : String
    , location : String
    -- , userLogin : String -- not sure what this is for? The user will already be logged in, at this point.
    , controlAgent : String
    , targetWeedName : String
    , targetWeedRank : String
    , targetWeedId : String
    , targetWeedTaxonName : String
    , weather : String
    , water : String
    , photos : String
    , province : String
    , sitename : String
    , date : String
    , noLeaves : String
    , noStems : String
    , noFlowers : String
    , noCapsules : String
    , maxHeight : String
    , noRamets : String
    , sizeOfInf : String
    , percentCover : String
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
      , province = "KZN"
      , sitename = "PMB Botanical Gardens"
      , date = "10/18/2019"
      , noLeaves = "114"
      , noStems = "0"
      , noFlowers = "0"
      , noCapsules = "0"
      , maxHeight = "136"
      , noRamets = "21"
      , sizeOfInf = "2x2m"
      , percentCover = ""
      , description = ""
      , csrf_token = token
      }
      , Cmd.none
    )


type Msg
    = NoOp
    -- Add more message constructors as needed

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )
        -- Add cases for other messages as needed


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
            [ Html.form [ Html.Attributes.action "#", Html.Attributes.method "post", Html.Attributes.class "form-group" ]
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

                -- -- User login
                -- , div [ class "field" ]
                --     [ label [] [ text "User login" ]
                --     , input [ type_ "text", id "userLogin", name "userLogin", value model.userLogin ] []
                --     ]

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
                    , input [ type_ "file", id "photos", name "photos" ] []
                    ]

                -- Water
                , div [ class "field" ]
                    [ label [] [ text "Water" ]
                    , textarea [ id "water", name "water" ] [ text model.water ]
                    ]

                -- Province
                , div [ class "field" ]
                    [ label [] [ text "Province" ]
                    , input [ type_ "text", id "province", name "province", value model.province ] []
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
                    , input [ type_ "text", id "noLeaves", name "noLeaves", value model.noLeaves ] []
                    ]

                -- No. stems
                , div [ class "field" ]
                    [ label [] [ text "No. stems" ]
                    , input [ type_ "text", id "noStems", name "noStems", value model.noStems ] []
                    ]

                -- No. flowers
                , div [ class "field" ]
                    [ label [] [ text "No. flowers" ]
                    , input [ type_ "text", id "noFlowers", name "noFlowers", value model.noFlowers ] []
                    ]

                -- No. capsules
                , div [ class "field" ]
                    [ label [] [ text "No. capsules" ]
                    , input [ type_ "text", id "noCapsules", name "noCapsules", value model.noCapsules ] []
                    ]

                -- Max height
                , div [ class "field" ]
                    [ label [] [ text "Max height" ]
                    , input [ type_ "text", id "maxHeight", name "maxHeight", value model.maxHeight ] []
                    ]

                -- No. ramets
                , div [ class "field" ]
                    [ label [] [ text "No. ramets" ]
                    , input [ type_ "text", id "noRamets", name "noRamets", value model.noRamets ] []
                    ]

                -- Size of inf.
                , div [ class "field" ]
                    [ label [] [ text "Size of inf." ]
                    , input [ type_ "text", id "sizeOfInf", name "sizeOfInf", value model.sizeOfInf ] []
                    ]

                -- % Cover
                , div [ class "field" ]
                    [ label [] [ text "% Cover" ]
                    , input [ type_ "text", id "percentCover", name "percentCover", value model.percentCover ] []
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
