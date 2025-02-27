module Profile exposing (..)
import Browser
import Html exposing (Html, div, h1, img, p, strong, text)
import Html.Attributes exposing (class, src, style, width)
import Http
import Json.Decode exposing (Decoder, field, string)

-- MODEL
type alias Profile =
    { givenName : String
    , picture : String
    , email : String
    }

type alias Model =
    Maybe Profile

type Msg
    = FetchProfile
    | GotProfile (Result Http.Error Profile)

-- JSON DECODER
profileDecoder : Decoder Profile
profileDecoder =
    Json.Decode.map3 Profile
        (field "given_name" string)
        (field "picture" string)
        (field "email" string)

-- INIT
init : () -> ( Model, Cmd Msg )
init _ =
    ( Nothing, fetchProfile )

fetchProfile : Cmd Msg
fetchProfile =
    Http.get
        { url = "/priv/profile" -- New API endpoint to get profile
        , expect = Http.expectJson GotProfile profileDecoder
        }


-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchProfile ->
            ( model, fetchProfile )

        GotProfile (Ok profile) ->
            ( Just profile, Cmd.none )

        GotProfile (Err _) ->
            ( Nothing, Cmd.none )

-- VIEW
view : Model -> Html Msg
view model =
    case model of
        Just profile ->
            div [ class "phx-hero" ]
                [ h1 []
                    [ text ("Welcome " ++ profile.givenName ++ "! ")
                    , img [ src profile.picture, width 32 ] []
                    ]
                , p []
                    [ text "You are "
                    , strong [] [ text "signed in" ]
                    , text " with your "
                    , strong [] [ text "Google Account" ]
                    , text " "
                    , strong [ style "color" "teal" ] [ text profile.email ]
                    ]
                ]

        Nothing ->
            div [] [ text "Something..." ]

-- MAIN
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }
