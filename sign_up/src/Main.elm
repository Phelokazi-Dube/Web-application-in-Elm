module Main exposing (..)

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

-- type Mode = Login | SignUp

init : Model
init =
  { username = ""
  , password = ""
  , confirmPassword = ""
  , mode = Login
  }

type Mode = Login | SignUp

type Msg
  = UpdateUsername String
  | UpdatePassword String
  | LoginMsg
  | SignUpMsg

update : Msg -> Model -> Model
update msg model =
  case msg of
    UpdateUsername username ->
      { model | username = username }

    UpdatePassword password ->
      { model | password = password }

    LoginMsg ->
      { model | mode = Login }

    SignUpMsg ->
      { model | mode = SignUp }

view : Model -> Html Msg
view model =
  div []
    [ input [ type_ "text", placeholder "Username", onInput UpdateUsername ] []
    , input [ type_ "password", placeholder "Password", onInput UpdatePassword ] []
    , case model.mode of
        Login ->
          button [ onClick LoginMsg ] [ text "Login" ]

        SignUp ->
          button [ onClick SignUpMsg ] [ text "Sign Up" ]
    ]
