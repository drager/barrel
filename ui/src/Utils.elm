module Utils
    exposing
        ( paperTextInput
        , paperNumberInput
        , paperPasswordInput
        , inputError
        , onPreventDefaultClick
        )

import Html exposing (Html)
import Html.Attributes exposing (attribute, type_, value)
import Html.Events
    exposing
        ( onInput
        , onFocus
        , onBlur
        , onWithOptions
        , defaultOptions
        )
import Form exposing (Form)
import Form.Field
import Form exposing (Form, Msg, FieldState, Msg(Input, Focus, Blur), InputType(..))
import Form.Field as Field exposing (Field, FieldValue(..))
import WebComponents.Paper as Paper
import Json.Decode


type alias Input e a =
    FieldState e a -> List (Html.Attribute Msg) -> Html Msg


{-| Based on: <https://github.com/etaque/elm-form/blob/master/src/Form/Input.elm>
-}
paperBaseInput : String -> (String -> FieldValue) -> InputType -> Input e String
paperBaseInput t toFieldValue inputType state attrs =
    let
        formAttrs =
            [ type_ t
            , value (state.value |> Maybe.withDefault "")
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


{-| Based on: <https://github.com/elm-lang/navigation/issues/13>
-}
onPreventDefaultClick : msg -> Html.Attribute msg
onPreventDefaultClick message =
    onWithOptions "click"
        { defaultOptions | preventDefault = True }
        (preventDefault2
            |> Json.Decode.andThen (maybePreventDefault message)
        )


preventDefault2 : Json.Decode.Decoder Bool
preventDefault2 =
    Json.Decode.map2
        (\a -> \b -> not (a || b))
        (Json.Decode.field "ctrlKey" Json.Decode.bool)
        (Json.Decode.field "metaKey" Json.Decode.bool)


maybePreventDefault : msg -> Bool -> Json.Decode.Decoder msg
maybePreventDefault msg preventDefault =
    case preventDefault of
        True ->
            Json.Decode.succeed msg

        False ->
            Json.Decode.fail "Normal link"
