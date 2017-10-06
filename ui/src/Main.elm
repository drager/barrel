module Main exposing (..)

import Html exposing (Html, text, div, img, h1)
import Form exposing (Form)
import Form.Error
import Form.Validate as Validate exposing (field, map5, Validation)
import Material
import Material.Dialog
import Material.Button as Button
import Material.Textfield
import Material.Card as Card
import Material.Layout as Layout
import Material.Options
import Material.List
import Styles exposing (..)
import Css
import Http
import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports exposing (..)
import Utils exposing (..)


-- type alias Connection = { host : String, username : String }
-- type alias ConnectionForm = { connection : Connection, password : String }
-- -- OR
-- type alias ConnectionForm = { host : String, username : String, password : String }
-- type alias ConnectionForm = { host : String, username : String, password : String }
-- type alias HasConnection a = { a | host : String, username : String }
-- functionThatTakesConnection : HasConnection a -> Something
{--TODO: Implement reconnection:
Go to a server route with the inactiveDbSessions, that are stored in localStorage and ask the server for some data with that session id.
If it succeeds, then we have a connection that works.
--}


type alias DbSessions =
    Dict SessionId Connection


type alias InactiveDbSessions =
    DbSessions


type alias ActiveDbSessions =
    DbSessions


type alias Mdl =
    Material.Model


type alias Connection =
    { host : String
    , portNumber : Int
    , username : String
    , database : String
    , retryFailed : Maybe Bool
    }


type alias ConnectionForm =
    { host : String
    , portNumber : Int
    , username : String
    , password : String
    , database : String
    }


type alias Model =
    { form : Form () ConnectionForm
    , mdl : Material.Model
    , activeDbSessions : ActiveDbSessions
    , inActiveDbSessions : InactiveDbSessions
    , databases : List Database
    }


type alias Database =
    { name : String
    , oid : Int
    }


type alias SessionId =
    String


type Msg
    = FormMsg Form.Msg
    | Mdl (Material.Msg Msg)
    | ReceiveFromLocalStorage ( String, Decode.Value )
    | ReceiveFromSessionStorage ( String, Decode.Value )
    | ConnectToDatabase Connection (Result Http.Error SessionId)
    | RetryConnection SessionId
    | Disconnect SessionId
    | NewRetriedConnection SessionId (Result Http.Error SessionId)
    | GetDatabases (Result Http.Error (List Database))


storageKey : String
storageKey =
    "dbSessions"


decodeDatabase : Decode.Decoder Database
decodeDatabase =
    Decode.map2 Database
        (Decode.field "name" Decode.string)
        (Decode.field "oid" Decode.int)


decodeSessionId : Decode.Decoder SessionId
decodeSessionId =
    Decode.field
        "session_id"
        Decode.string


encodeSessionId : SessionId -> Encode.Value
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


connectionEncoder : Connection -> Encode.Value
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


connect : ConnectionForm -> Http.Request SessionId
connect connection =
    Http.post (getApiUrl ++ "/connect")
        (connectionFormEncoder connection
            |> Http.jsonBody
        )
        decodeSessionId


getApiUrl : String
getApiUrl =
    "http://localhost:8000"


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


retryConnection : SessionId -> Cmd Msg
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


sessionIdRequest : SessionId -> String -> Decode.Decoder a -> Http.Request a
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


getDatabases : SessionId -> Cmd Msg
getDatabases sessionId =
    Http.send (GetDatabases)
        (sessionIdRequest sessionId (getApiUrl ++ "/databases") (Decode.list decodeDatabase))


validation : Validation () ConnectionForm
validation =
    map5 ConnectionForm
        (field "host" Validate.string)
        (field "portNumber" Validate.int)
        (field "username" Validate.string)
        (field "password" Validate.string)
        (field "database" Validate.string)


init : ( Model, Cmd Msg )
init =
    ( { form = Form.initial [] validation
      , mdl = Material.model
      , activeDbSessions = Dict.empty
      , inActiveDbSessions = Dict.empty
      , databases = []
      }
    , Ports.getItemInSessionStorage storageKey
    )


connectionDecoder : Decode.Decoder Connection
connectionDecoder =
    Decode.map5 Connection
        (Decode.field "host" Decode.string)
        (Decode.field "port" Decode.int)
        (Decode.field "username" Decode.string)
        (Decode.field "database" Decode.string)
        (Decode.maybe (Decode.field "retryFailed" Decode.bool))


storageDecoder : Decode.Decoder DbSessions
storageDecoder =
    Decode.dict connectionDecoder


storageEncoder : SessionId -> Connection -> Encode.Value
storageEncoder sessionId connection =
    let
        attributes =
            [ ( sessionId, (connectionEncoder connection) ) ]
    in
        Encode.object attributes


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
                        ( model, send user )

                _ ->
                    ( { model | form = Form.update validation formMsg model.form }, Cmd.none )

        Mdl msg_ ->
            Material.update Mdl msg_ model

        ConnectToDatabase connectionInfo (Ok sessionId) ->
            ( { model | activeDbSessions = Dict.insert sessionId connectionInfo model.activeDbSessions }
            , Cmd.batch
                [ pushItemInLocalStorage ( storageKey, (storageEncoder sessionId connectionInfo) )
                , pushItemInSessionStorage ( storageKey, (storageEncoder sessionId connectionInfo) )
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
                    (\session ->
                        ( { model | activeDbSessions = Dict.insert sessionId session model.activeDbSessions }
                        , pushItemInSessionStorage ( storageKey, (storageEncoder sessionId session) )
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

                updateKey : (Maybe Connection -> Maybe Connection) -> Dict String Connection
                updateKey session =
                    Dict.update failedSessionId session model.inActiveDbSessions
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
            let sessions =
                Dict.remove sessionId model.activeDbSessions
            in  ( { model | activeDbSessions = sessions }, Cmd.none ) 
 
        ReceiveFromLocalStorage ( storageKey, item ) ->
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

        ReceiveFromSessionStorage ( storageKey, item ) ->
            case Decode.decodeValue storageDecoder item of
                Ok sessions ->
                    ( { model | activeDbSessions = sessions }
                    , sessions
                        |> Dict.keys
                        |> List.map getDatabases
                        |> Cmd.batch
                    )

                Err err ->
                    Debug.log err
                        ( model, Ports.getItemInLocalStorage storageKey )

        GetDatabases (Ok databases) ->
            ( { model | databases = databases }, Cmd.none )

        GetDatabases (Err _) ->
            ( model, Cmd.none )


formField :
    Maybe String
    -> Model
    -> { b | value : Maybe String, path : String }
    -> String
    -> Material.Textfield.Property Msg
    -> String
    -> Html Msg
formField maybeValue model fieldObject label fieldType error =
    let
        -- _ =
        -- Debug.log "error" error
        render value =
            Material.Textfield.render
                Mdl
                [ 0 ]
                model.mdl
                [ Material.Textfield.label label
                , Material.Textfield.floatingLabel
                , fieldType
                , Material.Textfield.value <| Maybe.withDefault value fieldObject.value
                , onMaterialInput FormMsg fieldObject.path
                , onMaterialFocus FormMsg fieldObject.path
                , onMaterialBlur FormMsg fieldObject.path
                , Material.Textfield.error (error)
                    |> Material.Options.when (not <| String.isEmpty error)
                ]
                []
    in
        case maybeValue of
            Maybe.Just value ->
                render value

            Maybe.Nothing ->
                render ""


connectionFormView : Model -> Maybe Connection -> Html Msg
connectionFormView model connectionInfo =
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

        cardBlock =
            \content ->
                Card.text [] content

        -- fields states
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
            [ Button.raised
            , Button.primary
            , Button.ripple
            , onSubmit FormMsg
            ]
    in
        Card.view []
            [ cardBlock
                [ formField (Maybe.map .host connectionInfo) model host "Host" Material.Textfield.text_ (errorFor host)
                , formField (Maybe.map (.portNumber >> toString) connectionInfo) model portNumber "Port" Material.Textfield.text_ (errorFor portNumber)
                , formField (Maybe.map .username connectionInfo) model username "Username" Material.Textfield.text_ (errorFor username)
                , formField Nothing model password "Password" Material.Textfield.password (errorFor password)
                , formField (Maybe.map .database connectionInfo) model database "Database" Material.Textfield.text_ (errorFor database)
                , errorFor username |> text
                ]
            , Card.actions []
                [ Button.render Mdl
                    [ 5 ]
                    model.mdl
                    (if List.isEmpty (Form.getErrors form) |> not then
                        List.append [ Button.disabled ] buttonAttributes
                     else
                        buttonAttributes
                    )
                    [ text "Connect" ]
                ]
            ]


header : Model -> List (Html Msg)
header model =
    [ Layout.row
        []
        [ Layout.title [] [ text "Database manager" ]
        ]
    ]


mainView : Model -> List (Html Msg) -> List (Html Msg)
mainView model children =
    [ div
        [ styles
            [ Css.color (Css.hex "#000000")
            , Css.displayFlex
            ]
        ]
        children
    ]


listDatabasesView : Model -> Html Msg
listDatabasesView model =
    div []
        [ Material.List.ul []
            (List.map databaseListItemView model.databases)
        ]


databaseListItemView : Database -> Html Msg
databaseListItemView database =
    Material.List.li [ Material.List.withSubtitle ]
        [ Material.List.content []
            [ text database.name
            , Material.List.subtitle
                []
                [ text ("Oid: " ++ (database.oid |> toString)) ]
            ]
        ]


isSessionActive : SessionId -> ActiveDbSessions -> Bool
isSessionActive sessionId activeDbSessions =
    let
        activeKeys =
            Dict.keys activeDbSessions
    in
        Dict.member sessionId activeDbSessions


sessionListView : Model -> DbSessions -> Html Msg
sessionListView model dbSessions =
    div [ styles [ Css.flex (Css.int 1) ] ]
        [ Material.List.ul []
            (Dict.toList
                dbSessions
                |> List.map
                    (\( key, value ) ->
                        sessionListItemView model
                            { sessionId = key
                            , connection = value
                            }
                            (isSessionActive key model.activeDbSessions)
                    )
            )
        ]


connectionDialog : Model -> Maybe Connection -> Html Msg
connectionDialog model connectionMaybe =
    Material.Dialog.view
        []
        [ Material.Dialog.title [] [ text "Reconnect" ]
        , Material.Dialog.content []
            [ connectionFormView model connectionMaybe ]
        , Material.Dialog.actions []
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                [ Material.Dialog.closeOn "click" ]
                [ text "Reconnect" ]
            , Button.render Mdl
                [ 1 ]
                model.mdl
                [ Material.Dialog.closeOn "click" ]
                [ text "Cancel" ]
            ]
        ]


sessionListItemView : Model -> { sessionId : SessionId, connection : Connection } -> Bool -> Html Msg
sessionListItemView model { sessionId, connection } active =
    let
        failedSessionMaybe =
            Dict.get sessionId model.inActiveDbSessions
    in
        Material.List.li [ Material.List.withSubtitle ]
            [ Material.List.content []
                [ text connection.database
                , Material.List.subtitle
                    []
                    [ text (connection.host ++ ":" ++ (connection.portNumber |> toString)) ]
                ]
            , if not active then
                Material.List.content2 []
                    [ Button.render Mdl
                        [ 0 ]
                        model.mdl
                        [ Button.raised
                        , Button.primary
                        , Button.ripple
                        , Material.Dialog.openOn "click"
                        ]
                        [ text "Reconnect" ]
                    , case
                        (failedSessionMaybe
                            |> Maybe.andThen (.retryFailed)
                        )
                      of
                        Just failed ->
                            connectionDialog model failedSessionMaybe

                        Nothing ->
                            div [] []
                    ]
              else
                Material.List.content2 []
                    [ Button.render Mdl
                        [ 0 ]
                        model.mdl
                        [ Button.raised
                        , Button.primary
                        , Button.ripple
                        , Material.Options.onClick (Disconnect sessionId)
                        ]
                        [ text "Disconnect" ]
                    ]
            ]


view : Model -> Html Msg
view model =
    let
        children =
            [ div [ styles [ Css.flex (Css.int 1) ] ]
                [ if not (Dict.isEmpty model.activeDbSessions) then
                    div []
                        [ model.activeDbSessions
                            |> sessionListView model
                        , listDatabasesView model
                        ]
                  else if not (Dict.isEmpty model.inActiveDbSessions) then
                    model.inActiveDbSessions
                        |> sessionListView model
                  else
                    div
                        [ styles
                            [ Css.displayFlex
                            , Css.flexDirection Css.column
                            , Css.alignItems Css.center
                            , Css.flex (Css.int 1)
                            ]
                        ]
                        [ connectionFormView model Maybe.Nothing ]
                ]
            ]
    in
        div []
            [ Layout.render Mdl
                model.mdl
                [ Layout.fixedHeader, Layout.seamed ]
                { header = header model, drawer = [], main = mainView model children, tabs = ( [], [] ) }
            ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.localStorageGetItemResponse ReceiveFromLocalStorage
        , Ports.sessionStorageGetItemResponse ReceiveFromSessionStorage
        ]


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
