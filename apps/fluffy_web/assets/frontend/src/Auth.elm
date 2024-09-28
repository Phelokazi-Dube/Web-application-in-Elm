port module Auth exposing (..)

port signIn : () -> Cmd msg

port signedIn : (Bool -> msg) -> Sub msg