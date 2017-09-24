port module Ports exposing (..)

import Json.Encode


type alias Key =
    String


type alias Value =
    Json.Encode.Value


port localStorageGetItemResponse : (( Key, Value ) -> msg) -> Sub msg


port setItemInLocalStorage : ( Key, Value ) -> Cmd msg


port removeItemInLocalStorage : Key -> Cmd msg


port getItemInLocalStorage : Key -> Cmd msg


port clearLocalStorage : () -> Cmd msg


port pushItemInLocalStorage : ( Key, Value ) -> Cmd msg


port setItemInSessionStorage : ( Key, Value ) -> Cmd msg


port removeItemInSessionStorage : Key -> Cmd msg


port getItemInSessionStorage : Key -> Cmd msg


port clearSessionStorage : () -> Cmd msg


port pushItemInSessionStorage : ( Key, Value ) -> Cmd msg
