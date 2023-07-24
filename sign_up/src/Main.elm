module Main exposing (..)

import Browser
import Auth
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import Html.Events exposing (onClick)


type alias Model =
  { username : String
  , password : String
  , confirmPassword : String
  , mode : Mode
  }


type Mode = Login | SignUp


init : () -> (Model, Cmd Msg)
init flags =
  ( { username = ""
    , password = ""
    , confirmPassword = ""
    , mode = Login
    }
  , Cmd.none
  )


type Msg
  = UpdateUsername String
  | UpdatePassword String
  | LoginMsg
  | SignUpMsg


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UpdateUsername username ->
      ( { model | username = username }, Cmd.none )

    UpdatePassword password ->
      ( { model | password = password }, Cmd.none )

    LoginMsg ->
      ( { model | mode = Login }, Auth.signIn () )

    SignUpMsg ->
      ( { model | mode = SignUp }, Cmd.none )


view : Model -> Html Msg
view model =
  div [class "container"]
    
    [ node "link" 
            [ attribute "rel" "stylesheet"
            , attribute "href" "https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.5/font/bootstrap-icons.css"
            ] 
            []
      ,div [class "row"]
        [ div [ class "col-md-6 col-md-offset-3" ]
            [ h1 [ class "text-center" ]
                [ text "Google Account  "
                , node "ion-icon" 
                [ class "bi bi-google teal-color", attribute "name" "logo-google" ] []
                ]
            , div [class "form-group"]
                [ label [class "control-label"] [text "Username"]
                , input [class "form-control", type_ "text", placeholder "Username", onInput UpdateUsername] []
                ]
            , div [class "form-group"]
                [ label [class "control-label"] [text "Password"]
                , input [class "form-control", type_ "password", placeholder "Password", onInput UpdatePassword] []
                ]
            , case model.mode of
                Login ->
                  button [class "btn btn-primary btn-block", onClick LoginMsg] [text "Login"]

                SignUp ->
                  button [class "btn btn-primary btn-block", onClick SignUpMsg] [text "Sign Up"]
            ]
        ]
    ]



main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = \_ -> Sub.none
    }
