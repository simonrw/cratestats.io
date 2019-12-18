port module Main exposing (XType(..), main)

import Browser
import Html exposing (Html, div, h1, input, text)
import Html.Attributes exposing (id, type_)
import Html.Events exposing (keyCode, on, onInput)
import Http
import Json.Decode as D
import Json.Encode as E


type Model
    = Searching String
    | Found String


main : Program () Model Msg
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
            { name = "itertools"
            , version = Nothing
            }

        fetch =
            Http.post
                { url = "/api/v1/downloads"
                , body = Http.jsonBody (encodePlotRequest plotRequest)
                , expect = Http.expectJson GotDownloads decodeDownloads
                }
    in
    ( Searching "", Cmd.none )


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
    | InputUpdated String
    | KeyDown Int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDownloads res ->
            case res of
                Ok d ->
                    let
                        traces =
                            [ Line
                                { x = List.map (XDate << .date) d.downloads
                                , y = List.map (toFloat << .downloads) d.downloads
                                }
                            ]

                        layout =
                            {}

                        plotSpec1 =
                            { traces = traces
                            , layout = layout
                            , id = "plot-container"
                            }
                    in
                    ( model, elmToJs <| encodePlotSpec plotSpec1 )

                Err _ ->
                    ( model, Cmd.none )

        InputUpdated s ->
            ( Searching s, Cmd.none )


view : Model -> Html Msg
view model =
    let
        header =
            div []
                [ h1 [] [ text "Crate Stats" ]
                ]

        onKeyDown tagger =
            on "keydown" (D.map tagger keyCode)
    in
    case model of
        Searching _ ->
            div []
                [ header
                , input [ type_ "text", onInput InputUpdated, onKeyDown KeyDown ] []
                ]

        Found _ ->
            div []
                [ header
                , div [ id "plot-container" ] []
                , div [ id "plot-container2" ] []
                ]


type XType
    = XFloat Float
    | XDate String


type Trace
    = Scatter { x : List XType, y : List Float }
    | Line { x : List XType, y : List Float }


type alias Layout =
    {}


type alias PlotSpec =
    { traces : List Trace
    , layout : Layout
    , id : String
    }


encodePlotSpec : PlotSpec -> E.Value
encodePlotSpec spec =
    E.object
        [ ( "id", E.string spec.id )
        , ( "data", encodeTraces spec.traces )
        , ( "layout", E.null )
        ]


encodeTraces : List Trace -> E.Value
encodeTraces traces =
    E.list encodeTrace traces


encodeTrace : Trace -> E.Value
encodeTrace trace =
    case trace of
        Scatter s ->
            E.object
                [ ( "x", E.list encodeXType s.x )
                , ( "y", E.list E.float s.y )
                , ( "type", E.string "scatter" )
                , ( "mode", E.string "markers" )
                ]

        Line l ->
            E.object
                [ ( "x", E.list encodeXType l.x )
                , ( "y", E.list E.float l.y )
                , ( "type", E.string "scatter" )
                ]


encodeXType : XType -> E.Value
encodeXType typ =
    case typ of
        XFloat x ->
            E.float x

        XDate x ->
            E.string x


port elmToJs : E.Value -> Cmd msg
