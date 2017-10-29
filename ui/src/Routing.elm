module Routing exposing (..)

import Navigation
import UrlParser as Url exposing (s, top)


type Route
    = HomeRoute
    | DatabasesRoute
    | NotFoundRoute


route : Url.Parser (Route -> a) a
route =
    Url.oneOf
        [ Url.map HomeRoute top
        , Url.map DatabasesRoute (s "databases")
        ]


parseLocation : Navigation.Location -> Route
parseLocation location =
    case (Url.parsePath route location) of
        Just route ->
            route

        Nothing ->
            NotFoundRoute