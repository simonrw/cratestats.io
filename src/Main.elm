module Main exposing (..)

import Browser
import Html exposing (Html, button, div, text, h1, input, Attribute, h2)
import Html.Events exposing (onInput, on, keyCode)
import Html.Attributes exposing (type_, placeholder)
import Json.Decode as D


type alias Model =
    { currentText : String
    , crate : String
    }

main =
    Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = \_ -> Sub.none
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { currentText = ""
    , crate = ""
    }, Cmd.none )


type Msg
    = Submit String
    | KeyDown Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Submit text ->
            ({ model | currentText = text }, Cmd.none )

        KeyDown key ->
            if key == 13 then
                ( { model | crate = model.currentText }, Cmd.none )
            else
                ( model, Cmd.none )


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (D.map tagger keyCode)


view : Model -> Html Msg
view model =
    div []
    [ h1 [] [ text "Crate Stats" ]
    , input [ type_ "text", placeholder "Search for crate", onKeyDown KeyDown, onInput Submit ] []
    , viewCrate model
    ]


viewCrate : Model -> Html Msg
viewCrate model =
    div []
    [ h2 [] [ text model.crate ]
    ]
