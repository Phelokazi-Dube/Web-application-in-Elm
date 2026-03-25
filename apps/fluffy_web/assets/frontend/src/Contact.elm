module Contact exposing (..)

import Browser exposing (element)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Encode as Encode



-- Model
type alias Flags =
    { csrfToken : String
    , collection : String
    , baseUrl : String
    , searchText : String
    }


type alias Model =
    { name : String
    , surname : String
    , message : String
    , email : String
    , success : Bool
    , baseUrl : String
    }



-- Init


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { name = ""
      , surname = ""
      , message = ""
      , email = ""
      , success = False
      , baseUrl = flags.baseUrl
      }
    , Cmd.none
    )



-- Update


type Msg
    = Cancel
    | UpdateName String
    | UpdateSurname String
    | UpdateMessage String
    | UpdateEmail String
    | Submit
    | Submitted (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Cancel ->
            ( { model | name = "", surname = "", message = "", email = "", success = False }
            , Cmd.none
            )

        UpdateName newName ->
            ( { model | name = newName, success = False }, Cmd.none )

        UpdateSurname newSurname ->
            ( { model | surname = newSurname, success = False }, Cmd.none )

        UpdateMessage newMessage ->
            ( { model | message = newMessage, success = False }, Cmd.none )

        UpdateEmail newEmail ->
            ( { model | email = newEmail, success = False }, Cmd.none )

        Submit ->
            ( model, submitRequest model )

        Submitted (Ok _) ->
            ( { model
                | name = ""
                , surname = ""
                , email = ""
                , message = ""
                , success = True
            }
            , Cmd.none
            )

        Submitted (Err _) ->
            ( { model | success = False }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none

submitRequest : Model -> Cmd Msg
submitRequest model =
    Http.post
        { url = model.baseUrl ++ "/api/contact"
        , body =
            Http.jsonBody <|
                Encode.object
                    [ ( "name", Encode.string model.name )
                    , ( "surname", Encode.string model.surname )
                    , ( "email", Encode.string model.email )
                    , ( "message", Encode.string model.message )
                    ]
        , expect = Http.expectString Submitted
        }


view : Model -> Html Msg
view model =
    main_ [ class "container mx-auto px-4 py-8 animate-fade-in" ]
        [ h1 [ class "text-6xl font-bold text-left mb-4" ] [ text "Contact Us" ]
        , div [ class "grid grid-cols-1 md:grid-cols-2 gap-8" ]
            [ section [ id "contacts" ]
                [ if model.success then
                    div
                        [ class "max-w-2xl mx-auto mt-4 mb-4 p-4 rounded-md bg-green-100 text-green-800 text-center font-semibold shadow"
                        ]
                        [ text "✅ Email sent successfully!" ]
                else
                    text ""
                , div []
                    [ div [ class "mb-4" ]
                        [ label [] [ text "Name" ]
                        , input [ type_ "text", name "name", placeholder "Enter your name", required True, value model.name, onInput UpdateName, class "w-full px-3 py-2 border border-neutral-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-neutral-400" ] []
                        ]
                    , div [ class "mb-4" ]
                        [ label [] [ text "Surname" ]
                        , input [ type_ "text", name "surname", placeholder "Enter your surname", required True, value model.surname, onInput UpdateSurname, class "w-full px-3 py-2 border border-neutral-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-neutral-400" ] []
                        ]
                    , div [ class "mb-4" ]
                        [ label [] [ text "Message" ]
                        , textarea [ name "message", placeholder "Enter your message", required True, onInput UpdateMessage, class "w-full px-3 py-2 border border-neutral-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-neutral-400" ] [ text model.message ]
                        ]
                    , div [ class "mb-4" ]
                        [ label [] [ text "Email Address" ]
                        , input [ type_ "email", name "email", placeholder "Enter your email address", required True, value model.email, onInput UpdateEmail, class "w-full px-3 py-2 border border-neutral-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-neutral-400" ] []
                        ]
                    , div [ class "flex space-x-4" ]
                        [ button [ type_ "button", class "bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick Submit ] [ text "Send Message" ]
                        , button [ type_ "button", class "bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick Cancel ] [ text "Cancel" ]
                        ]
                    ]
                ]
            , section [ id "details" ]
                [ h2 [ class "text-4xl font-bold text-left mb-4" ] [ text "Support Information" ]
                , p [ class "text-2xl mb-4" ] [ text "For any inquiries or support, please don't hesitate to reach out to us using the contact form or the information below:" ]
                , ul [ class "space-y-2 text-2xl" ]
                    [ li [] [ i [ class "fa fa-envelope mb-4" ] [], text " cbcinfo@ru.ac.za" ]
                    , li [] [ i [ class "fa fa-phone mb-4" ] [], text " +27 46 603 8763" ]
                    , li [] [ i [ class "fa fa-map-marker mb-4" ] [], text " The Centre for Biological Control (CBC), Department of Zoology and Entomology, Life Science Building, Barrat Complex, African Street, Makhanda (Grahamstown)" ]
                    ]
                , div [ class "mt-6 mb-4" ]
                    [ h3 [ class "text-3xl font-semibold mb-2" ] [ text "Office Hours" ]
                    , p [ class "text-2xl" ] [ text "Monday - Friday: 8:00 AM - 4:00 PM" ]
                    , p [ class "text-2xl" ] [ text "Saturday - Sunday: Closed" ]
                    ]
                ]
            ]
        ]


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
