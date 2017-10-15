module WebComponents.Iron exposing (..)

import Html exposing (Html)


iron : String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
iron name =
    Html.node ("iron-" ++ name)


icon : List (Html.Attribute msg) -> List (Html msg) -> Html msg
icon =
    iron "icon"
