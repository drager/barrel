module Database exposing (..)

import Html exposing (Html, text)


type alias Model =
    {}


type Msg
    = NoOp


view : Model -> Html Msg
view model =
    Html.div [] [ text "Databases" ]


init : ( Model, Cmd Msg )
init =
    ( {}, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )
