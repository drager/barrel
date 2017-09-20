port module Ports exposing (..)

import Json.Encode


type alias Key =
    String


type alias Value =
    Json.Encode.Value


port setItemInLocalStorage : ( Key, Value ) -> Cmd msg


port removeItemInLocalStorage : Key -> Cmd msg


port clearLocalStorage : () -> Cmd msg


port setItemInSessionStorage : ( Key, Value ) -> Cmd msg


port removeItemInSessionStorage : Key -> Cmd msg


port clearSessionStorage : () -> Cmd msg
