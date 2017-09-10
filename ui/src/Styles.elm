module Styles exposing (..)

import Css exposing (asPairs, px)
import Html exposing (Html, Attribute, div)
import Html.Attributes


styles : List Css.Style -> Attribute msg
styles =
    Css.asPairs >> Html.Attributes.style
