module DownloadChart exposing (..)

import Dict exposing (Dict)
import TypedSvg exposing (svg)
import TypedSvg.Core exposing (Svg)
import CrateDetails exposing (CrateDetails)


type alias CrateVersion = (Int, Int)

type alias DownloadMap = Dict CrateVersion Int


view : CrateDetails -> Svg msg
view d =
    svg [] []
