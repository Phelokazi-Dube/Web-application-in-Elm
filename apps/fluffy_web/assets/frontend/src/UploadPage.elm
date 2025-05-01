module UploadPage exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)



-- The view function that creates the page


view : () -> Html msg
view _ =
    div [ class "flex flex-col min-h-screen" ]
        -- Main Content
        [ main_ [ class "flex-grow container mx-auto px-4 py-12 text-center" ]
            [ h1 [ class "text-5xl font-bold mb-4 text-gray-800" ]
                [ text "Upload Survey Data" ]
            , p [ class "text-x1 mb-8 text-gray-900" ]
                [ text "You're logged in! Choose how you'd like to upload your data:" ]
            , div [ class "flex justify-center gap-6 flex-wrap" ]
                [ a [ href "/uploading", class "bg-blue-700 text-white px-6 py-3 rounded-lg hover:bg-blue-600 transition" ]
                    [ text "Fill in Online Form" ]
                , a [ href "/csvupload", class "bg-green-700 text-white px-6 py-3 rounded-lg hover:bg-green-600 transition" ]
                    [ text "Upload CSV File" ]
                ]
            ]
        ]



-- The update function, which handles the app's state


update : msg -> () -> ()
update _ model =
    model



-- The initial model (empty tuple)


init : ()
init =
    ()



-- Main entry point for the Elm app


main =
    Browser.sandbox { init = init, update = update, view = view }
