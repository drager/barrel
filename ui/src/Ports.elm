port module Ports exposing (..)

import Json.Encode


type alias Key =
    String


type alias Value =
    Json.Encode.Value



-- TODO: Maybe make on and only "storageGetItemResponse" and "getItemFromStorage" instead.


port localStorageGetItemResponse : (( Key, Value ) -> msg) -> Sub msg


port sessionStorageGetItemResponse : (( Key, Value ) -> msg) -> Sub msg


port setItemInLocalStorage : ( Key, Value ) -> Cmd msg


port removeItemInLocalStorage : Key -> Cmd msg


port getItemInLocalStorage : Key -> Cmd msg


port clearLocalStorage : () -> Cmd msg


port pushItemInLocalStorage : ( Key, Value ) -> Cmd msg


port removeItemFromListInLocalStorage : ( Key, Value ) -> Cmd msg


port removeItemFromListInSessionStorage : ( Key, Value ) -> Cmd msg


port setItemInSessionStorage : ( Key, Value ) -> Cmd msg


port removeItemInSessionStorage : Key -> Cmd msg


port getItemInSessionStorage : Key -> Cmd msg


port clearSessionStorage : () -> Cmd msg


port pushItemInSessionStorage : ( Key, Value ) -> Cmd msg
