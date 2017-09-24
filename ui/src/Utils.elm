module Utils exposing (..)

import Form exposing (Form)
import Form.Field
import Material.Options as Options


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
