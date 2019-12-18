port module Main exposing (XType(..), main)

import Browser
import Html exposing (Html, div, h1, input, label, text)
import Html.Attributes exposing (for, id, type_)
import Html.Events exposing (keyCode, on, onInput)
import Http
import Json.Decode as D
import Json.Encode as E
import Semver


type
    CrateStatsError
    -- = TextError String
    = HttpError Http.Error
    | SemverParseError


type alias Model =
    { crateText : String
    , versionText : String
    , crate : Maybe String
    , version : Maybe Semver.Version
    , error : Maybe CrateStatsError
    }


initModel : Model
initModel =
    { crateText = ""
    , versionText = ""
    , crate = Nothing
    , version = Nothing
    , error = Nothing
    }


resetError : Model -> Model
resetError m =
    { m | error = Nothing }


type alias PlotRequest =
    { crate : String
    , version : Maybe String
    }


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
    ( initModel, Cmd.none )


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
                    ( resetError model, elmToJs <| encodePlotSpec plotSpec1 )

                Err e ->
                    ( { model | error = Just (HttpError e) }, Cmd.none )

        CrateNameUpdated s ->
            ( { model | crateText = s }, Cmd.none )

        CrateVersionUpdated s ->
            ( { model | versionText = s }, Cmd.none )

        KeyDown keyCode ->
            if keyCode == 13 then
                if model.versionText /= "" then
                    case Semver.parse model.versionText of
                        Just validVersion ->
                            let
                                newModel =
                                    { model | crate = Just model.crateText, version = Just validVersion }

                                plotRequest =
                                    { crate = newModel.crate |> Maybe.withDefault ""
                                    , version = newModel.version |> Maybe.map Semver.print
                                    }
                            in
                            ( resetError newModel, fetch plotRequest )

                        Nothing ->
                            ( { model | error = Just SemverParseError }, Cmd.none )

                else
                    let
                        newModel =
                            { model | crate = Just model.crateText, version = Nothing }

                        plotRequest =
                            { crate = newModel.crate |> Maybe.withDefault ""
                            , version = Nothing
                            }
                    in
                    ( resetError newModel, fetch plotRequest )

            else
                ( resetError model, Cmd.none )


view : Model -> Html Msg
view model =
    let
        header =
            div []
                [ h1 [] [ text "Crate Stats" ]
                , label [ for "crate-name-input" ] [ text "Crate name" ]
                , input [ id "crate-name-input", type_ "text", onInput CrateNameUpdated, onKeyDown KeyDown ] []
                , label [ for "crate-version-input" ] [ text "Crate version (optional)" ]
                , input [ id "crate-version-input", type_ "text", onInput CrateVersionUpdated, onKeyDown KeyDown ] []
                ]

        onKeyDown msg =
            on "keydown" (D.map msg keyCode)
    in
    case model.error of
        Nothing ->
            div []
                [ header
                , div [ id "plot-container" ] []
                ]

        Just e ->
            div []
                [ header
                , viewError e
                ]


viewError : CrateStatsError -> Html Msg
viewError error =
    case error of
        HttpError e ->
            case e of
                Http.BadUrl s ->
                    div [] [ text <| "Bad url: " ++ s ]

                Http.Timeout ->
                    div [] [ text "Network request timed out" ]

                Http.BadStatus code ->
                    div []
                        [ text <| "Bad status: " ++ String.fromInt code ]

                Http.BadBody s ->
                    div []
                        [ text <| "Bad body: " ++ s ]

                Http.NetworkError ->
                    div []
                        [ text "Network error" ]

        SemverParseError ->
            div [] [ text "Invalid semver" ]


type XType
    = XFloat Float
    | XDate String


type
    Trace
    -- = Scatter { x : List XType, y : List Float }
    = Line { x : List XType, y : List Float }


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
        -- Scatter s ->
        --     E.object
        --         [ ( "x", E.list encodeXType s.x )
        --         , ( "y", E.list E.float s.y )
        --         , ( "type", E.string "scatter" )
        --         , ( "mode", E.string "markers" )
        --         ]
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
