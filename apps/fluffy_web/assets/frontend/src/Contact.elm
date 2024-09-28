module Contact exposing (..)

import Browser exposing (sandbox)
import Html exposing (Html, div, nav, ul, li, a, input, button, text, h2, form, label, textarea, node)
import Html.Attributes exposing (class, href, type_, name, placeholder, required, method, action, attribute)
import Html.Events exposing (onClick, on, onInput)


-- Model
type alias Model =
    { name : String
    , surname : String
    , message : String
    , email : String
    }

-- Init
init : Model
init =
    { name = ""
    , surname = ""
    , message = ""
    , email = ""
    }

-- Update
type Msg
    = Cancel
    | UpdateName String
    | UpdateSurname String
    | UpdateMessage String
    | UpdateEmail String

update : Msg -> Model -> Model
update msg model =
    case msg of
        Cancel ->
            { model | name = "", surname = "", message = "", email = "" }

        UpdateName newName ->
            { model | name = newName }

        UpdateSurname newSurname ->
            { model | surname = newSurname }

        UpdateMessage newMessage ->
            { model | message = newMessage }

        UpdateEmail newEmail ->
            { model | email = newEmail }

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none

view : Model -> Html Msg
view model =
    div [ class "main" ]
        [   node "link" [
            attribute "rel" "stylesheet"
            , attribute "href" "/css/styling.css"
            ] [], 
            
            nav [ class "navbar" ]
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
                            [ a [ href "/survey" ] [ text "Map" ]
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
        , div [ class "body" ]
            [ form [ method "post", action "https://submit-form.com/f0t80tNVF" ]
                [ div []
                    [ label [] [ text "Name: " ]
                    , input [ type_ "text", name "name", placeholder "Enter your name", required True, onInput UpdateName ] [ text model.name ]
                    ]
                , div []
                    [ label [] [ text "Surname: " ]
                    , input [ type_ "text", name "surname", placeholder "Enter your surname", required True, onInput UpdateSurname ] [ text model.surname ]
                    ]
                , div []
                    [ label [] [ text "Message: " ]
                    , textarea [ name "message", placeholder "Enter your message", required True, onInput UpdateMessage ] [ text model.message ]
                    ]
                , div []
                    [ label [] [ text "Email Address: " ]
                    , input [ type_ "email", name "email", placeholder "Enter your email address", required True, onInput UpdateEmail ] [ text model.email ]
                    ]
                , button [ type_ "submit" ] [ text "Send Message" ]
                , button [ class "clear-btn", onClick Cancel ] [ text "Cancel" ]
                ]
            ]
        ]

main : Program () Model Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }
