module Database
    exposing
        ( Model
        , Msg
        , init
        , update
        , view
        , getDatabases
        , listDatabasesView
        , databaseListItemView
        )

import Html exposing (Html, div, text)
import Html.Attributes exposing (attribute, id)
import Css
import Dict exposing (Dict)
import Styles exposing (..)
import Http
import Json.Decode as Decode
import DbSessions
import Session
import WebComponents.Paper as Paper


type alias Databases =
    Dict DbSessions.SessionId (List Database)


type alias Database =
    { name : String
    , oid : Int
    }


type alias Model =
    { databases : Databases }


type Msg
    = GetDatabases DbSessions.SessionId (Result Http.Error (List Database))


init : ( Model, Cmd Msg )
init =
    ( { databases = Dict.empty }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetDatabases sessionId (Ok databases) ->
            ( { model
                | databases =
                    Dict.insert
                        sessionId
                        databases
                        model.databases
              }
            , Cmd.none
            )

        GetDatabases _ (Err _) ->
            ( model, Cmd.none )


decodeDatabase : Decode.Decoder Database
decodeDatabase =
    Decode.map2 Database
        (Decode.field "name" Decode.string)
        (Decode.field "oid" Decode.int)


getApiUrl : String
getApiUrl =
    "http://localhost:8000"


sessionIdRequest :
    DbSessions.SessionId
    -> String
    -> Decode.Decoder a
    -> Http.Request a
sessionIdRequest sessionId url decoder =
    Http.request
        { method = "GET"
        , headers = [ Http.header "X-Session-Id" sessionId ]
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson decoder
        , timeout = Nothing
        , withCredentials = False
        }


getDatabases : DbSessions.SessionId -> Cmd Msg
getDatabases sessionId =
    Http.send (GetDatabases sessionId)
        (sessionIdRequest sessionId (getApiUrl ++ "/databases") (Decode.list decodeDatabase))


listDatabasesView : Model -> Maybe Session.CurrentSession -> Html Msg
listDatabasesView model currentSession =
    div [ styles [ Css.flex (Css.int 1) ], attribute "role" "listbox" ]
        (Maybe.andThen
            (\{ sessionId } ->
                Dict.get sessionId model.databases
            )
            currentSession
            |> Maybe.withDefault []
            |> List.map databaseListItemView
        )


databaseListItemView : Database -> Html Msg
databaseListItemView database =
    Paper.item []
        [ Paper.itemBody [ attribute "two-line" "true" ]
            [ div [] [ text database.name ]
            , div
                [ attribute "secondary" "true"
                ]
                [ text ("Oid: " ++ (database.oid |> toString))
                ]
            ]
        ]


view : Model -> Session.Model -> Html Msg
view model sessionModel =
    Html.div [] [ listDatabasesView model sessionModel.currentSession ]
