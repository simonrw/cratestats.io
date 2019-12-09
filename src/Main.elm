module Main exposing (..)

import Browser
import Semver
import Dict exposing (Dict)
import Html exposing (Html, button, div, text, h1, input, Attribute, h2, p)
import Html.Events exposing (onInput, on, keyCode)
import Html.Attributes exposing (type_, placeholder, id)
import Ports
import Json.Decode as D
import Json.Encode as E
import Http
import CrateDetails exposing (CrateDetails, DownloadVersion)

type alias Model =
    { currentText : String
    , crate : String
    , crateDetails : Maybe CrateDetails
    }

main =
    Browser.element
    { init = init
    , update = update
    , view = view
    , subscriptions = \_ -> Sub.none
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { currentText = ""
    , crate = ""
    , crateDetails = Nothing
    }, Cmd.none )


type Msg
    = Submit String
    | KeyDown Int
    | GotCrateDetails (Result Http.Error CrateDetails)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Submit text ->
            ({ model | currentText = text }, Cmd.none )

        KeyDown key ->
            if key == 13 then
                ( model, fetchCrateDetails model.currentText )
            else
                ( model, Cmd.none )

        GotCrateDetails res ->
            case res of
                Ok d ->
                    let
                        -- Run all of these commands
                        cmds =
                            Cmd.batch
                                [ Ports.showDownloadsByVersion <| encodeCrateDetails "downloads-by-version-plot" d
                                ]
                    in
                    ( { model | crateDetails = Just d, crate = d.name } , cmds)

                Err e ->
                    ( model, Cmd.none )


fetchCrateDetails : String -> Cmd Msg
fetchCrateDetails crateName =
    Http.get
    { url = "/api/v1/crates/" ++ crateName
    , expect = Http.expectJson GotCrateDetails decodeCrateDetails
    }


-- Encoders

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



encodeCrateDetails : String -> CrateDetails -> E.Value
encodeCrateDetails elemId cd =
    E.object
        [ ( "id", E.string elemId )
        , ( "crate", E.list encodeVersion <| createPlotData cd )
        ]


encodeVersion : (String, Float) -> E.Value
encodeVersion (v, d) =
    E.object
    [ ( "version", E.string v )
    , ( "downloads", E.float d )
    ]


-- Decoders

decodeCrateDetails : D.Decoder CrateDetails
decodeCrateDetails =
    D.field "crates" <|
        D.map3 CrateDetails
            decodeCrateName
            decodeCrateDescription
            decodeCrateDownloads


decodeCrateName : D.Decoder String
decodeCrateName =
    D.field "crate" <|
        D.field "name" <|
            D.string
                

decodeCrateDescription : D.Decoder String
decodeCrateDescription =
    D.field "crate" <|
        D.field "description" <|
            D.string


decodeCrateDownloads : D.Decoder (List DownloadVersion)
decodeCrateDownloads =
    let
        decodeVersion =
            D.map2 DownloadVersion
                (D.field "num" D.string)
                (D.field "downloads" D.float)
    in
    D.field "versions" <|
        D.list decodeVersion

                
-- Event handlers


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (D.map tagger keyCode)


view : Model -> Html Msg
view model =
    div []
    [ h1 [] [ text "Crate Stats" ]
    , input [ type_ "text", placeholder "Search for crate", onKeyDown KeyDown, onInput Submit ] []
    , viewCrate model
    ]


viewCrate : Model -> Html Msg
viewCrate model =
    case model.crateDetails of
        Just details ->
            div []
            [ h2 [] [ text model.crate ]
            , p [] [ text details.description ]
            , div [ id "downloads-by-version-plot" ] []
            ]

        Nothing ->
            div [] []
