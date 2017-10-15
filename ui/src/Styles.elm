module Styles exposing (..)

import Css exposing (asPairs, px)
import Html exposing (Html, Attribute, div)
import Html.Attributes exposing (attribute)
import WebComponents.Iron as Iron


styles : List Css.Style -> Attribute msg
styles =
    Css.asPairs >> Html.Attributes.style


type alias Icon =
    { iconName : String
    , iconType : IconType
    }


type IconType
    = CustomMaterialIcon
    | MaterialIcon


customFontIcon : String -> Html msg
customFontIcon iconName =
    Html.i
        [ Html.Attributes.class ("mdi mdi-" ++ iconName)
        , styles [ Css.fontSize (Css.px 24) ]
        ]
        []


fontIcon : Icon -> Html msg
fontIcon { iconType, iconName } =
    case iconType of
        MaterialIcon ->
            Iron.icon [ attribute "icon" iconName ] []

        CustomMaterialIcon ->
            customFontIcon iconName


logo : List (Html msg) -> Html msg
logo children =
    div [ Html.Attributes.class "mdi mdi-database", Html.Attributes.attribute "style" "text-shadow: rgb(85, 60, 51) 0px 0px 0px, rgb(86, 61, 52) 1px 1px 0px, rgb(87, 62, 52) 2px 2px 0px, rgb(89, 62, 53) 3px 3px 0px, rgb(90, 63, 54) 4px 4px 0px, rgb(91, 64, 54) 5px 5px 0px, rgb(92, 65, 55) 6px 6px 0px, rgb(93, 65, 55) 7px 7px 0px, rgb(94, 66, 56) 8px 8px 0px, rgb(95, 67, 57) 9px 9px 0px, rgb(96, 68, 57) 10px 10px 0px, rgb(97, 68, 58) 11px 11px 0px, rgb(98, 69, 59) 12px 12px 0px, rgb(99, 70, 59) 13px 13px 0px, rgb(100, 71, 60) 14px 14px 0px, rgb(101, 71, 60) 15px 15px 0px, rgb(102, 72, 61) 16px 16px 0px, rgb(103, 73, 62) 17px 17px 0px, rgb(104, 73, 62) 18px 18px 0px, rgb(105, 74, 63) 19px 19px 0px, rgb(106, 75, 64) 20px 20px 0px, rgb(107, 76, 64) 21px 21px 0px, rgb(108, 76, 65) 22px 22px 0px, rgb(109, 77, 65) 23px 23px 0px, rgb(110, 78, 66) 24px 24px 0px, rgb(112, 79, 67) 25px 25px 0px, rgb(113, 79, 67) 26px 26px 0px, rgb(114, 80, 68) 27px 27px 0px, rgb(115, 81, 69) 28px 28px 0px, rgb(116, 82, 69) 29px 29px 0px, rgb(117, 82, 70) 30px 30px 0px, rgb(118, 83, 70) 31px 31px 0px, rgb(119, 84, 71) 32px 32px 0px, rgb(120, 85, 72) 33px 33px 0px, rgb(121, 85, 72) 34px 34px 0px; font-size: 100px; color: rgb(255, 255, 255); line-height: 180px; border-radius: 0%; text-align: center; background-color: rgb(122, 86, 73);z-index:1000;" ]
        children


ellipsis : List Css.Style
ellipsis =
    [ Css.whiteSpace Css.noWrap
    , Css.overflow Css.hidden
    , Css.textOverflow Css.ellipsis
    ]
