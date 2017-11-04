module Main exposing (..)

import Html exposing (Html, text, div, img, h1)
import Html.Attributes exposing (attribute, id)
import Html.Events exposing (onClick, onSubmit)
import Css
import Http
import Dict exposing (Dict)
import Json.Decode as Decode
import Ports exposing (..)
import WebComponents.AppLayout as AppLayout
import WebComponents.Paper as Paper
import Navigation


-- Own modules

import Styles exposing (..)
import Drawer
import Routing
import Database
import DbSessions
import Session


type alias Model =
    { route : Routing.Route
    , databases : List Database
    , drawerModel : Drawer.Model
    , databaseModel : Database.Model
    , sessionModel : Session.Model
    }


type alias Database =
    { name : String
    , oid : Int
    , sessionId : Maybe DbSessions.SessionId
    }


type Msg
    = OnLocationChange Navigation.Location
    | NewUrl String
    | GetDatabases DbSessions.SessionId (Result Http.Error (List Database))
    | DrawerMsg Drawer.Msg
    | DatabaseMsg Database.Msg
    | SessionMsg Session.Msg


decodeDatabase : Decode.Decoder Database
decodeDatabase =
    Decode.map3 Database
        (Decode.field "name" Decode.string)
        (Decode.field "oid" Decode.int)
        (Decode.maybe (Session.decodeSessionId))


getApiUrl : String
getApiUrl =
    "http://localhost:8000"


sessionIdRequest : DbSessions.SessionId -> String -> Decode.Decoder a -> Http.Request a
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


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        ( drawerModel, _ ) =
            Drawer.init

        ( databaseModel, _ ) =
            Database.init

        ( sessionModel, _ ) =
            Session.init
    in
        ( { route = Routing.parseLocation location
          , databases = []
          , drawerModel = drawerModel
          , databaseModel = databaseModel
          , sessionModel = sessionModel
          }
        , Ports.getItemInSessionStorage Session.dbSessionsStorageKey
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnLocationChange location ->
            ( { model | route = Routing.parseLocation location }, Cmd.none )

        NewUrl url ->
            ( model, Navigation.newUrl url )

        GetDatabases sessionId (Ok databases) ->
            let
                databasesWithSession =
                    List.map (\database -> { database | sessionId = Just sessionId }) databases
            in
                ( { model | databases = List.append databasesWithSession model.databases }, Cmd.none )

        GetDatabases _ (Err _) ->
            ( model, Cmd.none )

        SessionMsg sessionMsg ->
            let
                ( updatedSessionModel, sessionCmd ) =
                    Session.update sessionMsg model.sessionModel
            in
                ( { model | sessionModel = updatedSessionModel }, Cmd.map SessionMsg sessionCmd )

        DrawerMsg drawerMsg ->
            let
                ( updatedDrawerModel, drawerCmd ) =
                    Drawer.update drawerMsg model.drawerModel
            in
                ( { model | drawerModel = updatedDrawerModel }, Cmd.map DrawerMsg drawerCmd )

        DatabaseMsg databaseMsg ->
            let
                ( updatedDatabaseModel, databaseCmd ) =
                    Database.update databaseMsg model.databaseModel
            in
                ( { model | databaseModel = updatedDatabaseModel }, Cmd.map DatabaseMsg databaseCmd )


header : Model -> Html msg
header model =
    AppLayout.header
        [ attribute "shadow" "true"
        ]
        [ AppLayout.toolbar
            [ styles
                [ Css.color (Css.hex "#FFFFFF")
                ]
            ]
            [ Paper.iconButton
                [ attribute "icon" "menu"
                , attribute "drawer-toggle" "true"
                ]
                []
            , Html.div
                [ styles [ Css.paddingLeft (Css.px 16) ]
                , attribute "main-title" "true"
                ]
                [ text "Database manager" ]
            ]
        ]


mainView : Model -> Html Msg
mainView model =
    div
        [ styles
            [ Css.color (Css.hex "#000000")
            , Css.displayFlex
            ]
        ]
        [ div [ styles [ Css.flex (Css.int 1) ] ]
            [ if not (Dict.isEmpty model.sessionModel.activeDbSessions) then
                div []
                    [ Html.map SessionMsg
                        (model.sessionModel.activeDbSessions
                            |> Session.sessionListView model.sessionModel
                        )
                    , Html.map SessionMsg
                        (model.sessionModel.inActiveDbSessions
                            |> Session.sessionListView model.sessionModel
                        )
                    , div [] [ (Html.h1 [] [ (text "Databases") ]), listDatabasesView model ]
                    , Html.map SessionMsg (Session.connectionFormView model.sessionModel)
                    ]
              else if not (Dict.isEmpty model.sessionModel.inActiveDbSessions) then
                div []
                    [ Html.map SessionMsg
                        (model.sessionModel.inActiveDbSessions
                            |> Session.sessionListView model.sessionModel
                        )
                    , Html.map SessionMsg (Session.connectionFormView model.sessionModel)
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
                    [ Html.map SessionMsg (Session.connectionFormView model.sessionModel) ]
            ]
        ]


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
                [ text ("Oid: " ++ (database.oid |> toString)), text " - ", (Maybe.map text database.sessionId) |> Maybe.withDefault ("" |> text) ]
            ]
        ]


openDrawerList : Model -> Html msg
openDrawerList { sessionModel } =
    let
        list : DbSessions.SessionId -> DbSessions.Connection -> Maybe (List (Html msg))
        list sessionId connection =
            sessionModel.currentSession
                |> Maybe.map
                    (\cs ->
                        if not (cs.sessionId == sessionId) then
                            [ (Drawer.drawerItem
                                { iconName = "server"
                                , iconType = Styles.CustomMaterialIcon
                                }
                                (Html.div
                                    [ styles [ Css.displayFlex, Css.flexDirection (Css.column) ]
                                    ]
                                    [ Html.span
                                        [ styles [ Css.lineHeight (Css.initial) ]
                                        ]
                                        [ text (connection.database) ]
                                    , Html.span
                                        [ styles [ Css.color (Css.hex "#737373"), Css.fontWeight (Css.int (400)) ]
                                        ]
                                        [ Session.connectionString connection |> text ]
                                    ]
                                )
                              )
                            ]
                        else
                            []
                    )
    in
        Html.div []
            ([ (Drawer.drawerItem { iconName = "add", iconType = Styles.MaterialIcon } (text "New connection")) ]
                |> List.append
                    (Dict.toList
                        sessionModel.activeDbSessions
                        |> List.filterMap (\( sessionId, connection ) -> list sessionId connection)
                        |> List.concat
                    )
            )



-- Html.Events.onClick (NewUrl "databases")


closedDrawerList : Model -> Html msg
closedDrawerList model =
    Html.div []
        [ Html.div []
            [ Drawer.drawerItem
                { iconName = "database"
                , iconType = Styles.CustomMaterialIcon
                }
                (text "Databases")
            ]
        , Drawer.drawerItem
            { iconName = "server-off"
            , iconType = Styles.CustomMaterialIcon
            }
            (text "Inactive connections")
        ]


leftDrawer : Model -> Session.CurrentSession -> Html Msg
leftDrawer model currentSession =
    AppLayout.drawer [ attribute "slot" "drawer" ]
        (Maybe.map
            (\currentSession ->
                ((Drawer.drawer
                    { title = (text currentSession.connection.database)
                    , subTitle =
                        (text (Session.connectionString currentSession.connection))
                    , model = model.drawerModel
                    , openDrawerList = openDrawerList model
                    , closedDrawerList = closedDrawerList model
                    }
                 )
                    |> List.map (Html.map DrawerMsg)
                )
            )
            model.sessionModel.currentSession
            |> Maybe.withDefault ([])
        )


notFoundView : Html msg
notFoundView =
    Html.div [] [ text "Not found" ]


viewPage : Model -> Html Msg
viewPage model =
    case model.route of
        Routing.HomeRoute ->
            mainView model

        Routing.DatabasesRoute ->
            Database.view model.databaseModel |> Html.map DatabaseMsg

        Routing.NotFoundRoute ->
            notFoundView


view : Model -> Html Msg
view model =
    div []
        [ AppLayout.drawerLayout []
            [ (Maybe.map (\currentSession -> leftDrawer model currentSession) model.sessionModel.currentSession)
                |> Maybe.withDefault (div [] [])
            , AppLayout.headerLayout []
                [ header model
                , viewPage model
                , Html.div [ Html.Events.onClick (NewUrl "databases") ] [ text "AA" ]
                ]
            ]
        , Html.map SessionMsg (Session.connectionDialog model.sessionModel)
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map SessionMsg (Session.subscriptions model.sessionModel)


main : Program Never Model Msg
main =
    Navigation.program OnLocationChange
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
