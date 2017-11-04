module Session
    exposing
        ( CurrentSession
        , Model
        , Msg
        , init
        , update
        , subscriptions
        , dbSessionsStorageKey
        , connectionString
        , sessionListView
        , connectionDecoder
        , connectionEncoder
        , decodeSessionId
        , connectionFormView
        , connectionDialog
        )

import Css
import Dict exposing (Dict)
import Form exposing (Form)
import Form.Error
import Form.Field as Field exposing (Field)
import Form.Validate as Validate
import Html exposing (Html, div, text)
import Html.Attributes exposing (attribute, id)
import Html.Events exposing (onClick, onSubmit)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Styles exposing (..)
import WebComponents.Paper as Paper
import DbSessions
import Ports
import Utils


type alias ConnectionForm =
    { host : String
    , portNumber : Int
    , username : String
    , password : String
    , database : String
    }


type alias InactiveDbSessions =
    DbSessions.DbSessions


type alias ActiveDbSessions =
    DbSessions.DbSessions


type alias CurrentSession =
    { sessionId : DbSessions.SessionId
    , connection : DbSessions.Connection
    }


type Msg
    = ConnectToDatabase DbSessions.Connection (Result Http.Error DbSessions.SessionId)
    | RetryConnection DbSessions.SessionId
    | Disconnect DbSessions.SessionId
    | NewRetriedConnection DbSessions.SessionId (Result Http.Error DbSessions.SessionId)
    | SetReconnectionForm DbSessions.Connection
    | FormMsg Form.Msg
    | ReceiveFromLocalStorage ( String, Decode.Value )
    | ReceiveFromSessionStorage ( String, Decode.Value )


type alias Model =
    { activeDbSessions : ActiveDbSessions
    , inActiveDbSessions : InactiveDbSessions
    , currentSession : Maybe CurrentSession
    , form : Form () ConnectionForm
    }


dbSessionsStorageKey : String
dbSessionsStorageKey =
    "dbSessions"


storageDecoder : Decode.Decoder DbSessions.DbSessions
storageDecoder =
    Decode.dict connectionDecoder


storageEncoder : DbSessions.SessionId -> DbSessions.Connection -> Encode.Value
storageEncoder sessionId connection =
    let
        attributes =
            [ ( sessionId, (connectionEncoder connection) ) ]
    in
        Encode.object attributes


isSessionActive : DbSessions.SessionId -> ActiveDbSessions -> Bool
isSessionActive sessionId activeDbSessions =
    let
        activeKeys =
            Dict.keys activeDbSessions
    in
        DbSessions.member sessionId activeDbSessions


init : ( Model, Cmd Msg )
init =
    ( { form = Form.initial [] validation
      , activeDbSessions = Dict.empty
      , inActiveDbSessions = Dict.empty
      , currentSession = Nothing
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FormMsg formMsg ->
            case ( formMsg, Form.getOutput model.form ) of
                ( Form.Submit, Just user ) ->
                    let
                        b =
                            Debug.log "FORM" user
                    in
                        -- TODO: Should be possible to do with Form.Reset?
                        -- ( { model | form = Form.update validation (Form.Reset model.form) }
                        ( { model | form = Form.initial [] validation }
                        , send user
                        )

                _ ->
                    ( { model | form = Form.update validation formMsg model.form }, Cmd.none )

        ConnectToDatabase connectionInfo (Ok sessionId) ->
            ( { model
                | activeDbSessions = DbSessions.insert sessionId connectionInfo model.activeDbSessions
                , currentSession = Maybe.Just { sessionId = sessionId, connection = connectionInfo }
              }
            , Cmd.batch
                [ Ports.pushItemInLocalStorage ( dbSessionsStorageKey, (storageEncoder sessionId connectionInfo) )
                , Ports.pushItemInSessionStorage ( dbSessionsStorageKey, (storageEncoder sessionId connectionInfo) )
                ]
            )

        ConnectToDatabase connectionInfo (Err _) ->
            ( model, Cmd.none )

        RetryConnection sessionId ->
            ( model, retryConnection sessionId )

        NewRetriedConnection _ (Ok sessionId) ->
            let
                sessionMaybe =
                    Dict.get sessionId model.inActiveDbSessions
            in
                Maybe.map
                    (\connection ->
                        ( { model
                            | activeDbSessions = DbSessions.insert sessionId connection model.activeDbSessions
                          }
                        , Cmd.batch
                            [ Ports.pushItemInSessionStorage ( dbSessionsStorageKey, (storageEncoder sessionId connection) )

                            -- , getDatabases sessionId
                            ]
                        )
                    )
                    sessionMaybe
                    |> Maybe.withDefault
                        ( model
                        , Cmd.none
                        )

        NewRetriedConnection failedSessionId (Err err) ->
            let
                _ =
                    Debug.log "ERR" err

                failedSessionMaybe =
                    Dict.get failedSessionId model.inActiveDbSessions

                updateKey :
                    (Maybe DbSessions.Connection -> Maybe DbSessions.Connection)
                    -> Dict String DbSessions.Connection
                updateKey connection =
                    DbSessions.update failedSessionId connection model.inActiveDbSessions
            in
                ( { model
                    | inActiveDbSessions =
                        (Maybe.map
                            (\session -> { session | retryFailed = Just True })
                            |> updateKey
                        )
                  }
                , Cmd.none
                )

        Disconnect sessionId ->
            let
                sessions =
                    DbSessions.remove sessionId model.activeDbSessions

                activeSessionsCount =
                    DbSessions.size model.activeDbSessions

                sessionBefore : Maybe ( String, DbSessions.Connection )
                sessionBefore =
                    let
                        keys =
                            Dict.keys model.activeDbSessions
                    in
                        Dict.filter (\k v -> k /= sessionId) model.activeDbSessions
                            |> Dict.toList
                            |> List.head

                newModel =
                    if activeSessionsCount <= 1 then
                        { model | activeDbSessions = sessions, currentSession = Maybe.Nothing }
                    else
                        { model
                            | activeDbSessions = sessions
                            , currentSession =
                                (Maybe.map
                                    (\( session, connection ) ->
                                        { sessionId = session, connection = connection }
                                    )
                                    sessionBefore
                                )
                        }
            in
                ( newModel
                , Cmd.batch
                    [ Ports.removeItemFromListInLocalStorage ( dbSessionsStorageKey, (Encode.string sessionId) )
                    , Ports.removeItemFromListInSessionStorage ( dbSessionsStorageKey, (Encode.string sessionId) )
                    ]
                )

        SetReconnectionForm connection ->
            ( { model | form = Form.initial (initialFields connection) validation }, Cmd.none )

        ReceiveFromLocalStorage ( dbSessionsStorageKey, item ) ->
            case Decode.decodeValue storageDecoder item of
                Ok inActiveSessions ->
                    let
                        newModel =
                            { model | inActiveDbSessions = inActiveSessions }
                    in
                        ( newModel
                        , inActiveSessions
                            |> Dict.keys
                            |> List.map retryConnection
                            |> Cmd.batch
                        )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )

        ReceiveFromSessionStorage ( dbSessionsStorageKey, item ) ->
            case Decode.decodeValue storageDecoder item of
                Ok sessions ->
                    let
                        sessionIdMaybe =
                            List.head (Dict.keys sessions)

                        connectionMaybe =
                            List.head (Dict.values sessions)

                        newModel sessionId connection =
                            ( { model
                                | activeDbSessions = sessions
                                , currentSession = Maybe.Just { sessionId = sessionId, connection = connection }
                              }
                              -- TODO: Should be the line under
                            , Cmd.none
                              -- , sessions
                              --     |> Dict.keys
                              --     |> List.map getDatabases
                              --     -- |> List.append [ Ports.getItemInLocalStorage storageKey ]
                              --     |> Cmd.batch
                            )
                    in
                        (Maybe.map2
                            newModel
                            sessionIdMaybe
                            connectionMaybe
                        )
                            |> Maybe.withDefault ( model, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Ports.getItemInLocalStorage dbSessionsStorageKey )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.localStorageGetItemResponse ReceiveFromLocalStorage
        , Ports.sessionStorageGetItemResponse ReceiveFromSessionStorage
        ]


getApiUrl : String
getApiUrl =
    "http://localhost:8000"


connectionString : DbSessions.Connection -> String
connectionString connection =
    connection.host ++ ":" ++ (connection.portNumber |> toString)


decodeSessionId : Decode.Decoder DbSessions.SessionId
decodeSessionId =
    Decode.field
        "session_id"
        Decode.string


encodeSessionId : DbSessions.SessionId -> Encode.Value
encodeSessionId sessionId =
    let
        attributes =
            [ ( "sessionId", Encode.string sessionId )
            ]
    in
        Encode.string sessionId


connectionFormEncoder : ConnectionForm -> Encode.Value
connectionFormEncoder connection =
    let
        attributes =
            [ ( "host", Encode.string connection.host )
            , ( "port", Encode.int connection.portNumber )
            , ( "username", Encode.string connection.username )
            , ( "password", Encode.string connection.password )
            , ( "database", Encode.string connection.database )
            ]
    in
        Encode.object attributes


connectionDecoder : Decode.Decoder DbSessions.Connection
connectionDecoder =
    Decode.map5 DbSessions.Connection
        (Decode.field "host" Decode.string)
        (Decode.field "port" Decode.int)
        (Decode.field "username" Decode.string)
        (Decode.field "database" Decode.string)
        (Decode.maybe (Decode.field "retryFailed" Decode.bool))


connectionEncoder : DbSessions.Connection -> Encode.Value
connectionEncoder connection =
    let
        attributes =
            [ ( "host", Encode.string connection.host )
            , ( "port", Encode.int connection.portNumber )
            , ( "username", Encode.string connection.username )
            , ( "database", Encode.string connection.database )

            -- , ( "retryFailed", Encode.bool connection.retryFailed )
            ]
    in
        Encode.object attributes


validation : Validate.Validation () ConnectionForm
validation =
    Validate.map5 ConnectionForm
        (Validate.field "host" Validate.string)
        (Validate.field "portNumber" Validate.int)
        (Validate.field "username" Validate.string)
        (Validate.field "password" Validate.string)
        (Validate.field "database" Validate.string)


initialFields : DbSessions.Connection -> List ( String, Field )
initialFields connectionInfo =
    [ ( "host", Field.string connectionInfo.host )
    , ( "port", Field.string (connectionInfo.portNumber |> toString) )
    , ( "username", Field.string connectionInfo.username )
    , ( "database", Field.string connectionInfo.database )
    ]


connect : ConnectionForm -> Http.Request DbSessions.SessionId
connect connection =
    Http.post (getApiUrl ++ "/connect")
        (connectionFormEncoder connection
            |> Http.jsonBody
        )
        decodeSessionId


send : ConnectionForm -> Cmd Msg
send connectionInfo =
    Http.send
        (ConnectToDatabase
            { host = connectionInfo.host
            , portNumber = connectionInfo.portNumber
            , username = connectionInfo.username
            , database = connectionInfo.database
            , retryFailed = Nothing
            }
        )
        (connect connectionInfo)


retryConnection : DbSessions.SessionId -> Cmd Msg
retryConnection sessionid =
    Http.send
        (NewRetriedConnection sessionid)
        (Http.post
            (getApiUrl ++ "/connection/retry")
            (Encode.string sessionid
                |> Http.jsonBody
            )
            decodeSessionId
        )


getFailedMaybe : Maybe DbSessions.Connection -> Maybe Bool
getFailedMaybe failedSessionMaybe =
    failedSessionMaybe
        |> Maybe.andThen (.retryFailed)



-- VIEWS
-- TODO: Handle connection failures


connectionFormView : Model -> Html Msg
connectionFormView model =
    let
        -- error presenter
        errorFor field =
            case field.liveError of
                Just error ->
                    case error of
                        Form.Error.Empty ->
                            "The field is required"

                        Form.Error.InvalidInt ->
                            "Must be a number"

                        Form.Error.InvalidString ->
                            "The field is required"

                        _ ->
                            ""

                Nothing ->
                    ""

        form =
            model.form

        host =
            Form.getFieldAsString "host" form

        portNumber =
            Form.getFieldAsString "portNumber" form

        username =
            Form.getFieldAsString "username" form

        password =
            Form.getFieldAsString "password" form

        database =
            Form.getFieldAsString "database" form

        buttonAttributes =
            [ attribute "raised" "true"
            , attribute "primary" "true"
            , onClick Form.Submit
            ]
    in
        div []
            [ Utils.paperTextInput host
                ([ attribute "label" "Hostname" ]
                    ++ Utils.inputError (errorFor host)
                )
            , Utils.paperNumberInput portNumber
                ([ attribute "label" "Port" ]
                    ++ Utils.inputError (errorFor portNumber)
                )
            , Utils.paperTextInput username
                ([ attribute "label" "Username" ]
                    ++ Utils.inputError (errorFor username)
                )
            , Utils.paperPasswordInput password
                ([ attribute "label" "Password" ]
                    ++ Utils.inputError (errorFor password)
                )
            , Utils.paperTextInput database
                ([ attribute "label" "Database" ]
                    ++ Utils.inputError (errorFor database)
                )
            , Paper.button
                (if not (List.isEmpty (Form.getErrors form)) then
                    (List.append
                        buttonAttributes
                        [ (attribute
                            "disabled"
                            "true"
                          )
                        ]
                    )
                 else
                    buttonAttributes
                )
                [ text "Connect" ]
            ]
            |> Html.map FormMsg


connectionDialog : Model -> Html Msg
connectionDialog model =
    Paper.dialog
        [ id "reconnect_dialog"
        , attribute "entry-animation" "scale-up-animation"
        , attribute "exit-animation" "fade-out-animation"
        , attribute "with-backdrop" "true"
        ]
        [ Html.h2 [] [ text "Reconnect" ]
        , connectionFormView model
        ]


reconnectionView : Maybe DbSessions.Connection -> List (Html.Attribute Msg)
reconnectionView failedSessionMaybe =
    getFailedMaybe failedSessionMaybe
        |> Maybe.andThen
            (\_ ->
                (Maybe.map
                    (\failed ->
                        ([ onClick (SetReconnectionForm failed)
                         , attribute "onclick" "reconnect_dialog.open()"
                         ]
                        )
                    )
                    failedSessionMaybe
                )
            )
        |> Maybe.withDefault []


sessionListItemView :
    Model
    -> { sessionId : DbSessions.SessionId, connection : DbSessions.Connection }
    -> Bool
    -> Int
    -> Html Msg
sessionListItemView model { sessionId, connection } active index =
    let
        failedSessionMaybe =
            Dict.get sessionId model.inActiveDbSessions
    in
        div []
            [ Paper.item []
                [ Paper.itemBody [ attribute "two-line" "true" ]
                    [ div [] [ text connection.database ]
                    , div
                        [ attribute "secondary" "true"
                        ]
                        [ text (connectionString connection) ]
                    ]
                , if not active then
                    div []
                        [ Paper.button
                            (List.append
                                [ attribute "raised" "true"
                                , attribute "primary" "true"
                                ]
                                (reconnectionView
                                    failedSessionMaybe
                                )
                            )
                            [ text "Reconnect"
                            ]

                        -- , case
                        --     getFailedMaybe failedSessionMaybe
                        --   of
                        --     Just _ ->
                        --         connectionDialog model
                        --     Nothing ->
                        --         div [] []
                        ]
                  else
                    Paper.button
                        [ attribute "raised" "true"
                        , attribute "primary" "true"
                        , onClick (Disconnect sessionId)
                        ]
                        [ text "Disconnect" ]
                ]
            ]


sessionListView : Model -> DbSessions.DbSessions -> Html Msg
sessionListView model dbSessions =
    div [ styles [ Css.flex (Css.int 1) ], attribute "role" "listbox" ]
        (Dict.toList
            dbSessions
            |> List.indexedMap
                (\index ( key, value ) ->
                    sessionListItemView model
                        { sessionId = key
                        , connection = value
                        }
                        (isSessionActive key model.activeDbSessions)
                        index
                )
        )
