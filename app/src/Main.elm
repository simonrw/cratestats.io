port module Main exposing (XType(..), main)

import Browser
import Html exposing (Html, div, h1, input, label, option, select, text)
import Html.Attributes exposing (for, id, type_, value)
import Html.Events exposing (on, onInput)
import Http
import Json.Decode as D
import Json.Encode as E


type
    CrateStatsError
    -- = TextError String
    = HttpError Http.Error


type alias Model =
    { crateText : String
    , error : Maybe CrateStatsError
    , versions : List String
    }


initModel : Model
initModel =
    { crateText = ""
    , error = Nothing
    , versions = []
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


fetchDownloads : PlotRequest -> Cmd Msg
fetchDownloads plotRequest =
    Http.post
        { url = "/api/v1/downloads"
        , body = Http.jsonBody (encodePlotRequest plotRequest)
        , expect = Http.expectJson GotDownloads decodeDownloads
        }


fetchVersions : String -> Cmd Msg
fetchVersions name =
    Http.get
        { url = "/api/v1/versions/" ++ name
        , expect = Http.expectJson GotVersions decodeVersions
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initModel, Cmd.none )


type alias Downloads =
    { name : String
    , version : Maybe String
    , downloads : List Download
    }


type alias Versions =
    { versions : List String
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


decodeVersions : D.Decoder Versions
decodeVersions =
    D.map Versions
        (D.field "versions" (D.list D.string))


type Msg
    = GotDownloads (Result Http.Error Downloads)
    | GotVersions (Result Http.Error Versions)
    | CrateNameUpdated String
    | VersionSelected String


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

        GotVersions res ->
            case res of
                Ok v ->
                    ( { model | versions = v.versions }, Cmd.none )

                Err e ->
                    ( { model | error = Just (HttpError e) }, Cmd.none )

        CrateNameUpdated s ->
            ( { model | crateText = s }, fetchVersions s )

        VersionSelected s ->
            let
                plotRequest =
                    { crate = model.crateText
                    , version = Just s
                    }
            in
            ( model, fetchDownloads plotRequest )


view : Model -> Html Msg
view model =
    let
        selectOptions : List (Html Msg)
        selectOptions =
            [ option [ value "all" ] [ text "all" ] ] ++ List.map versionOption model.versions

        header =
            div []
                [ h1 [] [ text "Crate Stats" ]
                , label [ for "crate-name-input" ] [ text "Crate name" ]
                , input [ id "crate-name-input", type_ "text", onInput CrateNameUpdated ] []
                , select [ onInput VersionSelected ] selectOptions
                ]
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


versionOption : String -> Html msg
versionOption v =
    option [ value v ] [ text v ]


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
