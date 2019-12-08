port module Ports exposing (..)


import Json.Encode as E


port showDownloadsByVersion : E.Value -> Cmd msg

port showDownloadsTimeSeries : E.Value -> Cmd msg
