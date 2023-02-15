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

-- type Mode = Login | SignUp

init : () -> ( Model, Cmd Msg )
init flags =
  ( { username = ""
    , password = ""
    , confirmPassword = ""
    , mode = Login
    }
  , Cmd.none
  )

type Mode = Login | SignUp

type Msg
  = UpdateUsername String
  | UpdatePassword String
  | LoginMsg
  | SignUpMsg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    UpdateUsername username ->
      ( { model | username = username }
      , Cmd.none
      )

    UpdatePassword password ->
      ( { model | password = password }
      , Cmd.none
      )

    LoginMsg ->
      ( { model | mode = Login }
      , Auth.signIn ()
      )

    SignUpMsg ->
      ( { model | mode = SignUp }
      , Cmd.none
      )

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


main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = \_ -> Sub.none
    }
