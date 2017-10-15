module Utils exposing (..)

import Html exposing (Html)
import Html.Attributes exposing (attribute, type_, defaultValue)
import Html.Events exposing (onInput, onFocus, onBlur)
import Form exposing (Form)
import Form.Field
import Material.Options as Options
import Form exposing (Form, Msg, FieldState, Msg(Input, Focus, Blur), InputType(..))
import Form.Field as Field exposing (Field, FieldValue(..))
import WebComponents.Paper as Paper


type alias Input e a =
    FieldState e a -> List (Html.Attribute Msg) -> Html Msg


{-| Based on: <https://github.com/etaque/elm-form/blob/master/src/Form/Input.elm>
-}
paperBaseInput : String -> (String -> FieldValue) -> InputType -> Input e String
paperBaseInput t toFieldValue inputType state attrs =
    let
        formAttrs =
            [ type_ t
            , defaultValue (state.value |> Maybe.withDefault "")
            , onInput (toFieldValue >> (Input state.path inputType))
            , onFocus (Form.Focus state.path)
            , onBlur (Form.Blur state.path)
            ]
    in
        Paper.input (formAttrs ++ attrs) []


paperTextInput : Input e String
paperTextInput =
    paperBaseInput "text" String Text


paperNumberInput : Input e String
paperNumberInput =
    paperBaseInput "number" String Text


{-| Password input.
-}
paperPasswordInput : Input e String
paperPasswordInput =
    paperBaseInput "password" String Text


inputError : String -> List (Html.Attribute msg)
inputError message =
    if String.length (message) >= 1 then
        [ attribute "invalid" "true"
        , attribute "error-message" message
        ]
    else
        []


onSubmit : (Form.Msg -> msg) -> Options.Property c msg
onSubmit msg =
    Options.onClick << msg <| Form.Submit


onMaterialInput : (Form.Msg -> msg) -> String -> Options.Property c msg
onMaterialInput msg path =
    Options.onInput <| msg << Form.Input path Form.Text << Form.Field.String


onMaterialFocus : (Form.Msg -> msg) -> String -> Options.Property c msg
onMaterialFocus msg path =
    Options.onFocus << msg <| Form.Focus path


onMaterialBlur : (Form.Msg -> msg) -> String -> Options.Property c msg
onMaterialBlur msg path =
    Options.onBlur << msg <| Form.Blur path
