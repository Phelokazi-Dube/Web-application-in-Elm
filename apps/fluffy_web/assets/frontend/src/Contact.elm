module Contact exposing (..)

import Browser exposing (sandbox)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)



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
subscriptions _ =
    Sub.none


view : Model -> Html Msg
view model =
    main_ [ class "container mx-auto px-4 py-8 animate-fade-in" ]
        [ h1 [ class "text-6xl text-left mb-4" ] [ text "Contact Us" ]
        , div [ class "grid grid-cols-1 md:grid-cols-2 gap-8" ]
            [ section [ id "contacts" ]
                [ Html.form [ method "post", action "https://submit-form.com/f0t80tNVF" ]
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
                        [ button [ type_ "submit", class "bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700" ] [ text "Send Message" ]
                        , button [ type_ "button", class "bg-neutral-800 text-white px-4 py-2 rounded-md hover:bg-neutral-700", onClick Cancel ] [ text "Cancel" ]
                        ]
                    ]
                ]
            , section [ id "details" ]
                [ h2 [ class "text-4xl font-bold mb-4" ] [ text "Support Information" ]
                , p [ class "text-2xl mb-4" ] [ text "For any inquiries or support, please don't hesitate to reach out to us using the contact form or the information below:" ]
                , ul [ class "space-y-2 text-2xl" ]
                    [ li [] [ i [ class "fa fa-envelope" ] [], text " cbcinfo@ru.ac.za" ]
                    , li [] [ i [ class "fa fa-phone" ] [], text " +27 46 603 8763" ]
                    , li [] [ i [ class "fa fa-map-marker" ] [], text " The Centre for Biological Control (CBC), Department of Zoology and Entomology, Life Science Building, Barrat Complex, African Street, Makhanda (Grahamstown)" ]
                    ]
                , div [ class "mt-6" ]
                    [ h3 [ class "text-3xl font-semibold mb-2" ] [ text "Office Hours" ]
                    , p [ class "text-2xl" ] [ text "Monday - Friday: 8:00 AM - 4:00 PM" ]
                    , p [ class "text-2xl" ] [ text "Saturday - Sunday: Closed" ]
                    ]
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
