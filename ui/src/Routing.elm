module Routing exposing (..)

import Navigation
import UrlParser as Url exposing (s, top, (</>))


type Route
    = HomeRoute
    | DatabasesRoute
    | NewConnectionRoute
    | NotFoundRoute
    | InActiveConnectionsRoute


route : Url.Parser (Route -> a) a
route =
    Url.oneOf
        [ Url.map HomeRoute top
        , Url.map DatabasesRoute (s "databases")
        , Url.map NewConnectionRoute (s "connections" </> s "new")
        , Url.map InActiveConnectionsRoute (s "connections" </> s "inactive")
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

        DatabasesRoute ->
            "/databases"

        NewConnectionRoute ->
            "/connections/new"

        InActiveConnectionsRoute ->
            "/connections/inactive"

        NotFoundRoute ->
            "/not-found"
