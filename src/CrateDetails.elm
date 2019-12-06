module CrateDetails exposing (CrateDetails, DownloadVersion)


type alias DownloadVersion =
    { version : String
    , downloads : Float
    }


type alias CrateDetails =
    { name : String
    , description : String
    , versions : List DownloadVersion
    }




