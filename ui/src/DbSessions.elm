module DbSessions
    exposing
        ( DbSessions
        , Connection
        , SessionId
        , empty
        , member
        , insert
        , remove
        , update
        , size
        )

import Dict exposing (Dict)


type alias DbSessions =
    Dict SessionId Connection


type alias Connection =
    { host : String
    , portNumber : Int
    , username : String
    , database : String
    , retryFailed : Maybe Bool
    }


type alias SessionId =
    String


empty : DbSessions
empty =
    Dict.empty


member : SessionId -> DbSessions -> Bool
member sessionId dbSessions =
    Dict.member sessionId dbSessions


insert : SessionId -> Connection -> DbSessions -> DbSessions
insert sessionId connection dbSessions =
    Dict.insert sessionId connection dbSessions


remove : SessionId -> DbSessions -> DbSessions
remove sessionId dbSessions =
    Dict.remove sessionId dbSessions


update :
    SessionId
    -> (Maybe Connection -> Maybe Connection)
    -> DbSessions
    -> DbSessions
update sessionId connection dbSessions =
    Dict.update sessionId connection dbSessions


size : DbSessions -> Int
size dbSessions =
    Dict.size dbSessions
