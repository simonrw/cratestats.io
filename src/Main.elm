module Main exposing (..)

import Browser
import Html exposing (Html, button, div, text, h1, input, Attribute, h2, p)
import Html.Events exposing (onInput, on, keyCode)
import Html.Attributes exposing (type_, placeholder)
import Json.Decode as D
import Http
import DownloadChart
import CrateDetails exposing (CrateDetails)

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
                    ( { model | crateDetails = Just d, crate = d.name } , Cmd.none )

                Err e ->
                    ( model, Cmd.none )


fetchCrateDetails : String -> Cmd Msg
fetchCrateDetails crateName =
    Http.get
    { url = "/api/v1/crates/" ++ crateName
    , expect = Http.expectJson GotCrateDetails decodeCrateDetails
    }


-- Decoders

decodeCrateDetails : D.Decoder CrateDetails
decodeCrateDetails =
    D.field "crates" <|
        D.field "crate" <|
            D.map2 CrateDetails
                (D.field "description" D.string)
                (D.field "name" D.string)

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
            , DownloadChart.view details
            ]

        Nothing ->
            div [] []
