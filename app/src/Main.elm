port module Main exposing (..)

import Browser
import Dict exposing (Dict)
import Html exposing (Html, button, div, text, h1, input, Attribute, h2, p)
import Time
import Html.Events exposing (onInput, on, keyCode)
import Html.Attributes exposing (type_, placeholder, id)
import VegaLite exposing (..)
import Http
import Json.Decode as D
import Json.Encode as E

type alias Model =
  {}

main =
    Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = \_ -> Sub.none
    }


type alias PlotRequest =
    { name : String
    , version : Maybe String
    }


encodePlotRequest : PlotRequest -> E.Value
encodePlotRequest req =
    case req.version of
        Just version ->
            E.object
                [ ( "name", E.string req.name )
                , ( "version", E.string version )
                ]

        Nothing ->
            E.object
                [ ( "name", E.string req.name )
                ]



init : () -> ( Model, Cmd Msg )
init _ =
    let
        plotRequest =
            { name = "fitsio"
            , version = Nothing
            }

        fetch =
            Http.post
            { url = "/api/v1/downloads"
            , body = Http.jsonBody (encodePlotRequest plotRequest)
            , expect = Http.expectJson GotDownloads decodeDownloads
            }
    in
    ( {} , fetch )

type alias Downloads =
    { name : String
    , version : Maybe String
    , downloads : List Download
    }


type alias Download =
    { date : String
    , downloads : Int
    }


decodeDownloads : D.Decoder Downloads
decodeDownloads =
    D.map3 Downloads
        (D.field "name" D.string)
        (D.field "version" (D.nullable D.string))
        (D.field "downloads" (D.list decodeDownload))


decodeDownload : D.Decoder Download
decodeDownload =
    D.map2 Download
        (D.field "date" D.string)
        (D.field "downloads" D.int)

type Msg
  = GotDownloads (Result Http.Error Downloads)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDownloads res ->
            case res of
                Ok d ->
                    let
                        plotSpec1 =
                            { specs = myVis d
                            , id = "#plot-container"
                            }
                    in
                    ( model, elmToJs plotSpec1 )
                Err e ->
                    ( model, Cmd.none )

view : Model -> Html Msg
view model =
    div []
    [ h1 [] [ Html.text "CrateStats" ]
    , div [ id "plot-container" ] []
    , div [ id "plot-container2" ] []
    ]


type alias PlotSpec =
    { specs : Spec
    , id : String
    }

port elmToJs : PlotSpec -> Cmd msg

-- Visualisations

myVis : Downloads -> Spec
myVis d =
    let
        x =
            List.map .date d.downloads

        y =
            List.map (toFloat << .downloads) d.downloads

        data =
            dataFromColumns [ parse [ ( "Date", foDate "%Y-%m-%d" ) ] ]
            << dataColumn "Date" (strs x)
            << dataColumn "Downloads" (nums y)

        enc =
            encoding
                << position X [ pName "Date", pMType Temporal ]
                << position Y [ pName "Downloads", pMType Nominal ]
    in
    toVegaLite
    [ VegaLite.title "Hello world"
    , width 1024
    , height 800
    , data []
    , enc []
    , line []
    ]
