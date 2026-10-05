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
    main_ [ class "contact-page site-content-width animate-fade-in" ]
        [ h1 [ class "contact-page-title" ] [ text "Contact Us" ]
        , div [ class "contact-layout" ]
            [ section [ id "contacts" ]
                [ if model.success then
                    div
                        [ class "max-w-2xl mx-auto mt-4 mb-4 p-4 rounded-md bg-green-100 text-green-800 text-center font-semibold shadow"
                        ]
                        [ text "✅ Email sent successfully!" ]

                  else
                    text ""
                , div []
                    [ div [ class "contact-label" ]
                        [ label [] [ text "Name" ]
                        , input [ class "contact-field", type_ "text", name "name", placeholder "Enter your name", required True, value model.name, onInput UpdateName ] []
                        ]
                    , div [ class "contact-label" ]
                        [ label [] [ text "Surname" ]
                        , input [ class "contact-field", type_ "text", name "surname", placeholder "Enter your surname", required True, value model.surname, onInput UpdateSurname ] []
                        ]
                    , div [ class "contact-label" ]
                        [ label [] [ text "Message" ]
                        , textarea [ class "contact-field", name "message", placeholder "Enter your message", required True, onInput UpdateMessage ] [ text model.message ]
                        ]
                    , div [ class "contact-label" ]
                        [ label [] [ text "Email Address" ]
                        , input [ class "contact-field", type_ "email", name "email", placeholder "Enter your email address", required True, value model.email, onInput UpdateEmail ] []
                        ]
                    , div [ class "contact-buttons" ]
                        [ button [ type_ "button", onClick Submit ] [ text "Send Message" ]
                        , button [ type_ "button", onClick Cancel ] [ text "Cancel" ]
                        ]
                    ]
                ]
            , section [ id "details", class "contact-details" ]
                [ h2 [ class "contact-details-title" ] [ text "Support Information" ]
                , p [ class "contact-details-text" ] [ text "For any inquiries or support, please don't hesitate to reach out to us using the contact form or the information below:" ]
                , ul [ class "contact-details-list" ]
                    [ li [] [ i [ class "fa fa-envelope mb-4" ] [], text " cbcinfo@ru.ac.za" ]
                    , li [] [ i [ class "fa fa-phone mb-4" ] [], text " +27 46 603 8763" ]
                    , li [] [ i [ class "fa fa-map-marker mb-4" ] [], text " The Centre for Biological Control (CBC), Department of Zoology and Entomology, Life Science Building, Barrat Complex, African Street, Makhanda (Grahamstown)" ]
                    ]
                , div [ class "mt-6 mb-4" ]
                    [ h3 [ class "contact-office-title" ] [ text "Office Hours" ]
                    , p [ class "contact-details-text" ] [ text "Monday - Friday: 8:00 AM - 4:00 PM" ]
                    , p [ class "contact-details-text" ] [ text "Saturday - Sunday: Closed" ]
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
