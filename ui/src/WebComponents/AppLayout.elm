module WebComponents.AppLayout exposing (..)

import Html exposing (Html)


app : String -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
app name =
    Html.node ("app-" ++ name)


drawer : List (Html.Attribute msg) -> List (Html msg) -> Html msg
drawer =
    app "drawer"


drawerLayout : List (Html.Attribute msg) -> List (Html msg) -> Html msg
drawerLayout =
    app "drawer-layout"


toolbar : List (Html.Attribute msg) -> List (Html msg) -> Html msg
toolbar =
    app "toolbar"


headerLayout : List (Html.Attribute msg) -> List (Html msg) -> Html msg
headerLayout =
    app "header-layout"


header : List (Html.Attribute msg) -> List (Html msg) -> Html msg
header =
    app "header"
