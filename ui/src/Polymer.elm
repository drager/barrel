module Polymer exposing (..)

import Html exposing (Html)


paper : String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
paper name =
    Html.node ("paper-" ++ name)

app : String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
app name =
    Html.node ("app-" ++ name)


appDrawer : List (Html.Attribute msg) -> List (Html msg) -> Html msg
appDrawer =
    app "drawer"

button : List (Html.Attribute msg) -> List (Html msg) -> Html msg
button =
    paper "button"
