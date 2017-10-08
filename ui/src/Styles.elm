module Styles exposing (..)

import Css exposing (asPairs, px)
import Html exposing (Html, Attribute, div)
import Html.Attributes
import Material.Icon


styles : List Css.Style -> Attribute msg
styles =
    Css.asPairs >> Html.Attributes.style


type alias Icon =
    { iconName : String
    , iconSize : Int
    , isCustomIcon : Bool
    }


customFontIcon : String -> Html msg
customFontIcon iconName =
    Html.i
        [ Html.Attributes.class ("mdi mdi-" ++ iconName)
        , styles [ Css.fontSize (Css.px 24) ]
        ]
        []


fontIcon : Icon -> Html msg
fontIcon { isCustomIcon, iconName, iconSize } =
    if isCustomIcon then
        customFontIcon iconName
    else
        Material.Icon.view iconName []
