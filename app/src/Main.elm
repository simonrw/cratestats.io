port module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, div, text, h1, input, Attribute, h2, p)
import Html.Events exposing (onInput, on, keyCode)
import Html.Attributes exposing (type_, placeholder, id)
import VegaLite exposing (Spec, dataFromColumns, dataColumn, nums, encoding, position, Position(..), pMType, circle, Measurement(..), pName, toVegaLite)

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
    let
        plotSpec1 =
            { specs = myVis
            , id = "#plot-container"
            }

        plotSpec2 =
            { specs = myVis
            , id = "#plot-container2"
            }

        tasks =
            Cmd.batch
            [ elmToJs plotSpec1
            , elmToJs plotSpec2
            ]
    in
    ( {} , tasks )


type Msg
  = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
  (model, Cmd.none )

view : Model -> Html Msg
view model =
    div []
    [ h1 [] [ text "CrateStats" ]
    , div [ id "plot-container" ] []
    , div [ id "plot-container2" ] []
    ]


type alias PlotSpec =
    { specs : Spec
    , id : String
    }

port elmToJs : PlotSpec -> Cmd msg

-- Visualisations

myVis : Spec
myVis =
    let
        data =
            dataFromColumns []
            << dataColumn "x" (nums [10, 20, 30])

        enc =
            encoding
                << position X [ pName "x", pMType Quantitative ]
    in
    toVegaLite
    [ VegaLite.title "Hello world"
    , data []
    , enc []
    , circle []
    ]
