module Routing exposing (..)

import Html exposing (Html)
import Html.Attributes
import Css
import Navigation
import UrlParser as Url exposing (s, top, (</>))
import Styles exposing (styles)
import Utils


type alias Model =
    { route : Route
    }


type Msg
    = OnLocationChange Navigation.Location
    | NewRoute Route


type Route
    = HomeRoute
    | DatabasesRoute
    | NewConnectionRoute
    | NotFoundRoute
    | InActiveConnectionsRoute
    | NewDatabaseRoute


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        route =
            parseLocation location
    in
        ( { route = route }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnLocationChange location ->
            let
                route =
                    parseLocation location
            in
                ( { model | route = route }, Cmd.none )

        NewRoute route ->
            model ! [ Navigation.newUrl (routeToString route) ]


route : Url.Parser (Route -> a) a
route =
    Url.oneOf
        [ Url.map HomeRoute top
        , Url.map DatabasesRoute (s "databases")
        , Url.map NewConnectionRoute (s "connections" </> s "new")
        , Url.map InActiveConnectionsRoute (s "connections" </> s "inactive")
        , Url.map NewDatabaseRoute (s "databases" </> s "new")
        ]


parseLocation : Navigation.Location -> Route
parseLocation location =
    case (Url.parsePath route location) of
        Just route ->
            route

        Nothing ->
            NotFoundRoute


routeToString : Route -> String
routeToString route =
    case route of
        HomeRoute ->
            "/"

        NewConnectionRoute ->
            "/connections/new"

        InActiveConnectionsRoute ->
            "/connections/inactive"

        DatabasesRoute ->
            "/databases"

        NewDatabaseRoute ->
            "/databases/new"

        NotFoundRoute ->
            "/not-found"


linkTo : Route -> List (Html.Attribute Msg) -> List (Html.Html Msg) -> Html Msg
linkTo route attributes children =
    Html.a
        ([ styles [ Css.cursor (Css.pointer) ]
         , Html.Attributes.href (routeToString route)
         , Utils.onPreventDefaultClick (NewRoute route)
         ]
            ++ attributes
        )
        children
