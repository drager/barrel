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
import Routing


type alias Databases =
    Dict DbSessions.SessionId RemoteDatabases


type RemoteDatabases
    = Ready
    | Fetching
    | Success (List Database)
    | Error Http.Error


type alias Database =
    { name : String
    , oid : Int
    }


type alias Model =
    { databases : Databases }


type Msg
    = GetDatabases DbSessions.SessionId (Result Http.Error (List Database))
    | RoutingMsg Routing.Msg


init : ( Model, Cmd Msg )
init =
    ( { databases = Dict.empty }, Cmd.none )


update : Msg -> Model -> Routing.Model -> ( Model, Cmd Msg )
update msg model routingModel =
    case msg of
        GetDatabases sessionId (Result.Ok databases) ->
            ( { model
                | databases =
                    (Dict.insert
                        sessionId
                        (Success databases)
                        Dict.empty
                    )
              }
            , Cmd.none
            )

        GetDatabases sessionId (Result.Err err) ->
            ( { model
                | databases =
                    (Dict.insert
                        sessionId
                        (Error err)
                        Dict.empty
                    )
              }
            , Cmd.none
            )

        RoutingMsg routingMsg ->
            let
                ( _, routingCmd ) =
                    Routing.update routingMsg routingModel
            in
                ( model, Cmd.map RoutingMsg routingCmd )


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


listDatabasesView : RemoteDatabases -> Maybe Session.CurrentSession -> Html Msg
listDatabasesView database currentSession =
    case database of
        Ready ->
            div [] [ text "Init" ]

        Fetching ->
            Styles.centeredSpinner [ styles [ Css.paddingTop (Css.px 16) ] ] []

        Success databases ->
            div [ styles [ Css.flex (Css.int 1) ] ]
                [ div [ attribute "role" "listbox" ]
                    (databases
                        |> List.map databaseListItemView
                    )
                , (Routing.linkTo Routing.NewDatabaseRoute
                    []
                    [ Paper.fab
                        [ styles [ Css.backgroundColor (Css.hex "#cddc39") ]
                        , attribute "icon" "add"
                        ]
                        []
                    ]
                  )
                    |> Html.map RoutingMsg
                ]

        Error err ->
            div [] [ text "Failed to get data" ]


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
    let
        remoteDatabases : RemoteDatabases
        remoteDatabases =
            (Maybe.andThen
                (\{ sessionId } ->
                    Dict.get sessionId model.databases
                )
                sessionModel.currentSession
                |> Maybe.withDefault Fetching
            )
    in
        Html.div [] [ listDatabasesView remoteDatabases sessionModel.currentSession ]
