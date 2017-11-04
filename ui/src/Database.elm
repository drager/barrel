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
import Styles exposing (..)
import Http
import Json.Decode as Decode
import DbSessions
import Session
import WebComponents.Paper as Paper


type alias Database =
    { name : String
    , oid : Int
    , sessionId : Maybe DbSessions.SessionId
    }


type alias Model =
    { databases : List Database }


type Msg
    = GetDatabases DbSessions.SessionId (Result Http.Error (List Database))


init : ( Model, Cmd Msg )
init =
    ( { databases = [] }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetDatabases sessionId (Ok databases) ->
            let
                databasesWithSession =
                    List.map
                        (\database ->
                            { database | sessionId = Just sessionId }
                        )
                        databases
            in
                ( { model
                    | databases =
                        List.append
                            databasesWithSession
                            model.databases
                  }
                , Cmd.none
                )

        GetDatabases _ (Err _) ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    Html.div [] [ text "Databases" ]


decodeDatabase : Decode.Decoder Database
decodeDatabase =
    Decode.map3 Database
        (Decode.field "name" Decode.string)
        (Decode.field "oid" Decode.int)
        (Decode.maybe (Session.decodeSessionId))


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


listDatabasesView : Model -> Html Msg
listDatabasesView model =
    div [ styles [ Css.flex (Css.int 1) ], attribute "role" "listbox" ]
        (List.map databaseListItemView model.databases)


databaseListItemView : Database -> Html Msg
databaseListItemView database =
    Paper.item []
        [ Paper.itemBody [ attribute "two-line" "true" ]
            [ div [] [ text database.name ]
            , div
                [ attribute "secondary" "true"
                ]
                [ text ("Oid: " ++ (database.oid |> toString))
                , text " - "
                , (Maybe.map text database.sessionId)
                    |> Maybe.withDefault ("" |> text)
                ]
            ]
        ]
