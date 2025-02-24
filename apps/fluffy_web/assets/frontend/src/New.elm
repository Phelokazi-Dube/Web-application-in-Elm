module New exposing (..)

import Browser
import Html exposing (Html, a, img, h1, p, section, text)
import Html.Attributes exposing (class, href, src, alt)


type alias Model =
    { oauthGoogleUrl : String }

init : Model
init =
    { oauthGoogleUrl = "http://localhost:4000" }


view : Model -> Html msg
view model =
    section [ class "phx-hero" ]
        [ h1 [] [ text "Welcome to Awesome App!" ]
        , p [] [ text "To get started, login to your Google Account:" ]
        , a [ href model.oauthGoogleUrl ]
            [ img [ src "https://i.imgur.com/Kagbzkq.png", alt "Sign in with Google" ] []
            ]
        ]

update : msg -> Model -> Model
update _ model = model

main =
    Browser.sandbox { init = init, update = update, view = view }