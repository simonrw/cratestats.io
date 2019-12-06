module DownloadChart exposing (view)

import Axis
import Dict exposing (Dict)
import Semver
import TypedSvg exposing (svg, g, rect)
import Scale exposing (BandScale, defaultBandConfig, ContinuousScale)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Attributes exposing (transform, viewBox)
import TypedSvg.Attributes.InPx exposing (width, height, x, y)
import TypedSvg.Types exposing (Transform(..))
import CrateDetails exposing (CrateDetails, DownloadVersion)


w : Float
w =
    900


h : Float
h =
    450


padding : Float
padding =
    30


parseVersion : String -> String
parseVersion s =
    case Semver.parse s of
        Just v ->
            (String.fromInt v.major) ++ "." ++ (String.fromInt v.minor)

        Nothing ->
            -- TODO: make this better
            ""


updateMap : DownloadVersion -> Dict String Float -> Dict String Float
updateMap  dv dict =
    let
        crateVersion =
            parseVersion dv.version

        updateFn old =
            case old of
                Nothing ->
                    Just dv.downloads

                Just p ->
                    Just (dv.downloads + p)

    in
    Dict.update crateVersion updateFn dict


createPlotData : CrateDetails -> List (String, Float)
createPlotData d =
    let
        downloadMap =
            List.foldl updateMap Dict.empty d.versions
    in
    Dict.toList downloadMap


xScale : List (String, Float) -> BandScale String
xScale model =
    List.map Tuple.first model
    |> Scale.band { defaultBandConfig | paddingInner = 0.1, paddingOuter = 0.2 } ( 0, w - 2 * padding )


yScale : ContinuousScale Float
yScale =
    Scale.linear ( h - 2 * padding, 0 ) (0, 1000000)


versionFormat : String -> String
versionFormat s =
    s


xAxis : List (String, Float) -> Svg msg
xAxis model =
    Axis.bottom [] (Scale.toRenderable versionFormat (xScale model))


yAxis : Svg msg
yAxis =
    Axis.left [] yScale


column : BandScale String -> (String, Float) -> Svg msg
column scale (version, downloads) =
    g [] 
        [ rect
            [ x <| Scale.convert scale version
            , y <| Scale.convert yScale downloads
            , width <| Scale.bandwidth scale
            , height <| h - Scale.convert yScale downloads - 2 * padding
            ]
            []
        ]

view : CrateDetails -> Svg msg
view d =
    let
        plotData =
            createPlotData d
    in
    svg [ viewBox 0 0 w h ] 
    [ g [ transform [ Translate (padding - 1) (h - padding) ] ]
        [ xAxis plotData ]
    , g [ transform [ Translate (padding - 1) padding ] ]
        [ yAxis ]
    , g [ transform [ Translate padding padding ] ]  <|
        List.map (column (xScale plotData)) plotData
    ]
