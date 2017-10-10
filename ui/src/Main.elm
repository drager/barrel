module Main exposing (..)

import Html exposing (Html, text, div, img, h1)
import Form exposing (Form)
import Form.Error
import Form.Field as Field exposing (Field)
import Form.Validate as Validate exposing (field, map5, Validation)
import Material
import Material.Dialog
import Material.Typography
import Material.Button as Button
import Material.Button
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


type alias CurrentSession =
    { sessionId : SessionId
    , connection : Connection
    }


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
    , currentSession : Maybe CurrentSession
    }


type alias Database =
    { name : String
    , oid : Int
    , sessionId : Maybe SessionId
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
    | GetDatabases SessionId (Result Http.Error (List Database))
    | SetReconnectionForm Connection


storageKey : String
storageKey =
    "dbSessions"


decodeDatabase : Decode.Decoder Database
decodeDatabase =
    Decode.map3 Database
        (Decode.field "name" Decode.string)
        (Decode.field "oid" Decode.int)
        (Decode.maybe (decodeSessionId))


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
    Http.send (GetDatabases sessionId)
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
      , currentSession = Nothing
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
                        -- TODO: Should be possible to do with Form.Reset?
                        -- ( { model | form = Form.update validation (Form.Reset model.form) }
                        ( { model | form = Form.initial [] validation }
                        , send user
                        )

                _ ->
                    ( { model | form = Form.update validation formMsg model.form }, Cmd.none )

        Mdl msg_ ->
            Material.update Mdl msg_ model

        ConnectToDatabase connectionInfo (Ok sessionId) ->
            ( { model
                | activeDbSessions = Dict.insert sessionId connectionInfo model.activeDbSessions
                , currentSession = Maybe.Just { sessionId = sessionId, connection = connectionInfo }
              }
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
                        , Cmd.batch
                            [ pushItemInSessionStorage ( storageKey, (storageEncoder sessionId session) )
                            , getDatabases sessionId
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
            let
                sessions =
                    Dict.remove sessionId model.activeDbSessions
            in
                ( { model | activeDbSessions = sessions }
                , Cmd.batch
                    [ Ports.removeItemFromListInLocalStorage ( storageKey, (Encode.string sessionId) )
                    , Ports.removeItemFromListInSessionStorage ( storageKey, (Encode.string sessionId) )
                    ]
                )

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
                            , sessions
                                |> Dict.keys
                                |> List.map getDatabases
                                -- |> List.append [ Ports.getItemInLocalStorage storageKey ]
                                |>
                                    Cmd.batch
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
                        ( model, Ports.getItemInLocalStorage storageKey )

        GetDatabases sessionId (Ok databases) ->
            let
                databasesWithSession =
                    List.map (\database -> { database | sessionId = Just sessionId }) databases
            in
                ( { model | databases = List.append databasesWithSession model.databases }, Cmd.none )

        GetDatabases _ (Err _) ->
            ( model, Cmd.none )

        SetReconnectionForm connection ->
            ( { model | form = Form.initial (initialFields connection) validation }, Cmd.none )


formField :
    Model
    -> { b | value : Maybe String, path : String }
    -> String
    -> Material.Textfield.Property Msg
    -> String
    -> Html Msg
formField model fieldObject label fieldType error =
    Material.Textfield.render
        Mdl
        [ 0 ]
        model.mdl
        [ Material.Textfield.label label
        , Material.Textfield.floatingLabel
        , fieldType
        , Material.Textfield.value <| Maybe.withDefault "" fieldObject.value
        , onMaterialInput FormMsg fieldObject.path
        , onMaterialFocus FormMsg fieldObject.path
        , onMaterialBlur FormMsg fieldObject.path
        , Material.Textfield.error (error)
            |> Material.Options.when (not <| String.isEmpty error)
        ]
        []


initialFields : Connection -> List ( String, Field )
initialFields connectionInfo =
    [ ( "host", Field.string connectionInfo.host )
    , ( "port", Field.string (connectionInfo.portNumber |> toString) )
    , ( "username", Field.string connectionInfo.username )
    , ( "database", Field.string connectionInfo.database )
    ]


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
                [ formField model host "Host" Material.Textfield.text_ (errorFor host)
                , formField model portNumber "Port" Material.Textfield.text_ (errorFor portNumber)
                , formField model username "Username" Material.Textfield.text_ (errorFor username)
                , formField model password "Password" Material.Textfield.password (errorFor password)
                , formField model database "Database" Material.Textfield.text_ (errorFor database)
                , errorFor username |> text
                ]
            , Card.actions []
                [ Button.render Mdl
                    [ 5 ]
                    model.mdl
                    (if not (List.isEmpty (Form.getErrors form)) then
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
                [ text ("Oid: " ++ (database.oid |> toString))
                , text " - "
                , (Maybe.map text database.sessionId) |> Maybe.withDefault ("" |> text)
                ]
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
        ]


connectionDialog : Model -> Html Msg
connectionDialog model =
    Material.Dialog.view
        []
        [ Material.Dialog.title [] [ text "Reconnect" ]
        , Material.Dialog.content []
            [ connectionFormView model ]
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


getFailedMaybe : Maybe Connection -> Maybe Bool
getFailedMaybe failedSessionMaybe =
    failedSessionMaybe
        |> Maybe.andThen (.retryFailed)


reconnectionView : Maybe Connection -> List (Material.Options.Property c Msg)
reconnectionView failedSessionMaybe =
    getFailedMaybe failedSessionMaybe
        |> Maybe.andThen
            (\_ ->
                (Maybe.map
                    (\failed ->
                        ([ Material.Options.onClick (SetReconnectionForm failed)
                         , Material.Dialog.openOn
                            "click"
                         ]
                        )
                    )
                    failedSessionMaybe
                )
            )
        |> Maybe.withDefault []


sessionListItemView : Model -> { sessionId : SessionId, connection : Connection } -> Bool -> Int -> Html Msg
sessionListItemView model { sessionId, connection } active index =
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
                        [ index ]
                        model.mdl
                        (List.append
                            [ Button.raised
                            , Button.primary
                            , Button.ripple
                            ]
                            (reconnectionView
                                failedSessionMaybe
                            )
                        )
                        [ text "Reconnect" ]
                    , case
                        getFailedMaybe failedSessionMaybe
                      of
                        Just _ ->
                            connectionDialog model

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


drawerItem : Icon -> String -> Html msg
drawerItem icon itemText =
    div
        [ styles
            [ Css.padding (Css.px 16)
            , Css.displayFlex
            , Css.displayFlex
            , Css.alignItems (Css.center)
            ]
        ]
        [ Html.span [ styles [ Css.color (Css.rgba 0 0 0 0.54) ] ] [ fontIcon icon ]
        , Html.span [ styles [ Css.paddingLeft (Css.px 32) ] ]
            [ Material.Options.styled
                Html.span
                [ Material.Typography.body2 ]
                [ text itemText ]
            ]
        ]


drawerHeader : CurrentSession -> Model -> Html Msg
drawerHeader currentSession model =
    let
        titleRow =
            div
                [ styles
                    [ Css.paddingLeft (Css.px 16)
                    , Css.paddingRight (Css.px 16)
                    , Css.paddingBottom (Css.px 16)
                    ]
                ]
                [ Html.span [ styles [ Css.color (Css.hex "#ffffff") ] ]
                    [ Material.Options.styled
                        Html.span
                        [ Material.Typography.body2 ]
                        [ text currentSession.connection.database ]
                    ]
                , Html.div [ styles [ Css.displayFlex, Css.alignItems (Css.center) ] ]
                    [ Html.div
                        [ styles
                            [ Css.flex (Css.int 1)
                            , Css.color (Css.hex "#ffffff")
                            ]
                        ]
                        [ Material.Options.styled
                            Html.span
                            [ Material.Typography.body1 ]
                            [ text
                                (currentSession.connection.host
                                    ++ ":"
                                    ++ (currentSession.connection.portNumber |> toString)
                                )
                            ]
                        ]
                    , Html.div
                        [ styles
                            [ Css.color (Css.hex "#ffffff")
                            ]
                        ]
                        [ Material.Button.render Mdl
                            []
                            model.mdl
                            [ Material.Button.icon
                            ]
                            [ fontIcon { iconName = "keyboard_arrow_down", iconType = MaterialIcon } ]
                        ]
                    ]
                ]
    in
        div
            [ styles
                [ Css.backgroundColor (Css.rgb 96 125 139)
                , Css.backgroundSize Css.cover
                ]
            ]
            [ div [ styles [ Css.padding (Css.px 16), Css.paddingTop (Css.px 32) ] ]
                [ div
                    [ styles
                        [ Css.borderRadius (Css.px 50)
                        , Css.backgroundColor (Css.hex "#ffffff")
                        , Css.width (Css.px 56)
                        , Css.height (Css.px 56)
                        , Css.displayFlex
                        , Css.justifyContent (Css.center)
                        , Css.alignItems (Css.center)
                        ]
                    ]
                    [ fontIcon { iconName = "server", iconType = CustomMaterialIcon } ]
                ]
            , titleRow
            ]


drawer : Model -> List (Html Msg)
drawer model =
    [ div
        []
        [ (Maybe.map (\currentSession -> drawerHeader currentSession model) model.currentSession
            |> Maybe.withDefault (div [] [])
          )
        , div
            [ styles
                [ Css.displayFlex
                , Css.flex (Css.int 1)
                , Css.flexDirection (Css.column)
                ]
            ]
            [ drawerItem
                { iconName = "server"
                , iconType = CustomMaterialIcon
                }
                "Active connections"
            , drawerItem
                { iconName = "server-off"
                , iconType = CustomMaterialIcon
                }
                "Inactive connections"
            ]
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
                        , model.inActiveDbSessions
                            |> sessionListView model
                        , listDatabasesView model
                        , connectionFormView model
                        ]
                  else if not (Dict.isEmpty model.inActiveDbSessions) then
                    div []
                        [ model.inActiveDbSessions
                            |> sessionListView model
                        , connectionFormView model
                        ]
                  else
                    div
                        [ styles
                            [ Css.displayFlex
                            , Css.flexDirection Css.column
                            , Css.alignItems Css.center
                            , Css.flex (Css.int 1)
                            ]
                        ]
                        [ connectionFormView model ]
                ]
            ]
    in
        div []
            [ Layout.render Mdl
                model.mdl
                [ Layout.fixedHeader, Layout.seamed, Layout.fixedDrawer ]
                { header = header model, drawer = drawer model, main = mainView model children, tabs = ( [], [] ) }
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
