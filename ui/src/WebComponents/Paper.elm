module WebComponents.Paper exposing (..)

import Html exposing (Html)


paper : String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
paper name =
    Html.node ("paper-" ++ name)


button : List (Html.Attribute msg) -> List (Html msg) -> Html msg
button =
    paper "button"


iconButton : List (Html.Attribute msg) -> List (Html msg) -> Html msg
iconButton =
    paper "icon-button"


drawer : List (Html.Attribute msg) -> List (Html msg) -> Html msg
drawer =
    paper "drawer"


drawerTitle : List (Html.Attribute msg) -> List (Html msg) -> Html msg
drawerTitle =
    paper "drawer-title"


item : List (Html.Attribute msg) -> List (Html msg) -> Html msg
item =
    paper "item"


itemBody : List (Html.Attribute msg) -> List (Html msg) -> Html msg
itemBody =
    paper "item-body"


iconItem : List (Html.Attribute msg) -> List (Html msg) -> Html msg
iconItem =
    paper "icon-item"


dialog : List (Html.Attribute msg) -> List (Html msg) -> Html msg
dialog =
    paper "dialog"


input : List (Html.Attribute msg) -> List (Html msg) -> Html msg
input =
    paper "input"


spinner : List (Html.Attribute msg) -> List (Html msg) -> Html msg
spinner =
    paper "spinner"
