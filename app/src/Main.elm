port module Main exposing (XType(..), main)

import Browser
import Html exposing (Html, a, div, h1, input, label, text)
import Html.Attributes exposing (for, id, type_)
import Html.Events exposing (keyCode, on, onClick, onInput)
import Http
import Json.Decode as D
import Json.Encode as E
import Semver


type Model
    = Searching PlotRequest
    | Found PlotRequest


type alias PlotRequest =
    { crate : String
    , version : Maybe String
    }


crateText : Model -> Maybe String
crateText model =
    case model of
        Searching s ->
            Just s.crate

        _ ->
            Nothing


versionText : Model -> Maybe String
versionText model =
    case model of
        Searching s ->
            s.version

        _ ->
            Nothing


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


encodePlotRequest : PlotRequest -> E.Value
encodePlotRequest req =
    case req.version of
        Just version ->
            E.object
                [ ( "name", E.string req.crate )
                , ( "version", E.string version )
                ]

        Nothing ->
            E.object
                [ ( "name", E.string req.crate )
                ]


fetch : PlotRequest -> Cmd Msg
fetch plotRequest =
    Http.post
        { url = "/api/v1/downloads"
        , body = Http.jsonBody (encodePlotRequest plotRequest)
        , expect = Http.expectJson GotDownloads decodeDownloads
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Searching { crate = "", version = Nothing }, Cmd.none )


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
    | CrateNameUpdated String
    | CrateVersionUpdated String
    | KeyDown Int
    | ResetApp


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

        CrateNameUpdated s ->
            case model of
                Searching { crate, version } ->
                    ( Searching { crate = s, version = version }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        CrateVersionUpdated s ->
            case model of
                Searching { crate, version } ->
                    ( Searching { crate = crate, version = Just s }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        KeyDown keyCode ->
            if keyCode == 13 then
                -- Send off the data for the crate
                case model of
                    Searching r ->
                        case r.version of
                            Just v ->
                                case Semver.parse v of
                                    Just _ ->
                                        ( Found r, fetch r )

                                    Nothing ->
                                        ( Searching r, Cmd.none )

                            Nothing ->
                                ( Found r, fetch r )

                    Found _ ->
                        ( model, Cmd.none )

            else
                ( model, Cmd.none )

        ResetApp ->
            ( Searching { crate = "", version = Nothing }, Cmd.none )


view : Model -> Html Msg
view model =
    let
        header =
            div []
                [ h1 [] [ text "Crate Stats" ]
                ]

        onKeyDown msg =
            on "keydown" (D.map msg keyCode)
    in
    case model of
        Searching _ ->
            div []
                [ header
                , label [ for "crate-name-input" ] [ text "Crate name" ]
                , input [ id "crate-name-input", type_ "text", onInput CrateNameUpdated, onKeyDown KeyDown ] []
                , label [ for "crate-version-input" ] [ text "Crate version (optional)" ]
                , input [ id "crate-version-input", type_ "text", onInput CrateVersionUpdated, onKeyDown KeyDown ] []
                ]

        Found _ ->
            div []
                [ header
                , a [ onClick ResetApp ] [ text "Back" ]
                , div [ id "plot-container" ] []
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
