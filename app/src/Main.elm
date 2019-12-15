module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, div, text, h1, input, Attribute, h2, p)
import Html.Events exposing (onInput, on, keyCode)
import Html.Attributes exposing (type_, placeholder, id)

type alias Model =
  {}

main =
    Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = \_ -> Sub.none
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( {} , Cmd.none )


type Msg
  = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
  (model, Cmd.none )

-- Encoders

view : Model -> Html Msg
view model =
    div []
    [ h1 [] [ text "CrateStats" ]
    ]
