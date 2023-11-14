module Main exposing (..)

import Auth
import Browser
import UploadingData exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Browser.Navigation exposing (load)


type alias Model =
  { mode : Mode
  }

type Mode = Login

init : () -> (Model, Cmd Msg)
init flags =
  ( { mode = Login }
  , Cmd.none
  )

type Msg
  = LoginMsg
  | LoginSuccessful

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    LoginMsg ->
      ( { model | mode = Login }, Auth.signIn () )

    LoginSuccessful ->
      -- Load a new page when the user is logged in
      ({ model | mode = Login }, load "/uploading")

view : Model -> Html Msg
view model =
  case model.mode of
    Login ->
      div
        [class "container"]
        [ div
          [class "row"]
          [ div
            [ class "col-md-6 col-md-offset-3" ]
            [ h1
              [ class "text-center" ]
              [ button
                  [ class "btn btn-primary btn-block"
                  , onClick LoginMsg
                  ]
                  [ text "Login with Google  "
                  , node "ion-icon"
                    [ class "bi bi-google teal-color", attribute "name" "logo-google" ]
                    []
                  ]
              ]
            ]
          ]
        ]

subscriptions : Model -> Sub Msg
subscriptions _ =
  Auth.signedIn
    (\valueFromJavaScript ->
      if valueFromJavaScript then
        LoginSuccessful
      else
        LoginMsg
    )

main =
  Browser.element
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }
