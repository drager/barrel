module Main exposing (..)

import Html exposing (Html, text, div, h1)
import Html.Attributes exposing (attribute, id)
import Html.Events exposing (onClick)
import Css
import Dict exposing (Dict)
import WebComponents.AppLayout as AppLayout
import WebComponents.Paper as Paper
import Navigation


-- Own modules

import Styles exposing (..)
import Routing
import Database
import DbSessions
import Session


type alias Model =
    { drawerState : DrawerState
    , databaseModel : Database.Model
    , sessionModel : Session.Model
    , routingModel : Routing.Model
    }


type Msg
    = OnLocationChange Navigation.Location
    | DatabaseMsg Database.Msg
    | SessionMsg Session.Msg
    | RoutingMsg Routing.Msg
    | ToggleDrawer
    | SetCurrentSession Session.CurrentSession


type DrawerState
    = DrawerOpen
    | DrawerClosed


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    let
        ( sessionModel, sessionCmd ) =
            Session.init

        ( databaseModel, databaseCmd ) =
            Database.init

        ( routingModel, routingCmd ) =
            Routing.init location

        newModel =
            { databaseModel = databaseModel
            , sessionModel = sessionModel
            , drawerState = DrawerClosed
            , routingModel = routingModel
            }
    in
        ( newModel
        , Cmd.batch
            [ Cmd.map SessionMsg sessionCmd
            , Cmd.map DatabaseMsg databaseCmd
            ]
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnLocationChange location ->
            let
                route =
                    Routing.parseLocation location

                oldRoutingModel =
                    model.routingModel

                newRoutingModel =
                    ({ oldRoutingModel | route = route })

                newModel =
                    ({ model | routingModel = newRoutingModel })

                commands =
                    commandsForRoute route model.sessionModel.currentSession
            in
                ( newModel, commands )

        RoutingMsg routingMsg ->
            let
                ( updatedRoutingModel, routingCmd ) =
                    Routing.update routingMsg model.routingModel

                commands =
                    Cmd.batch
                        [ Cmd.map RoutingMsg routingCmd
                        , commandsForRoute updatedRoutingModel.route model.sessionModel.currentSession
                        ]
            in
                ( { model | routingModel = updatedRoutingModel }, commands )

        SessionMsg sessionMsg ->
            let
                ( updatedSessionModel, sessionCmd ) =
                    Session.update sessionMsg model.sessionModel

                commands =
                    Cmd.batch
                        [ Cmd.map SessionMsg sessionCmd
                        , commandsForRoute model.routingModel.route updatedSessionModel.currentSession
                        ]
            in
                ( { model | sessionModel = updatedSessionModel }, commands )

        DatabaseMsg databaseMsg ->
            let
                ( updatedDatabaseModel, databaseCmd ) =
                    Database.update databaseMsg model.databaseModel model.routingModel
            in
                ( { model | databaseModel = updatedDatabaseModel }, Cmd.map DatabaseMsg databaseCmd )

        ToggleDrawer ->
            let
                newDrawerState =
                    case model.drawerState of
                        DrawerOpen ->
                            DrawerClosed

                        DrawerClosed ->
                            DrawerOpen
            in
                ( { model | drawerState = newDrawerState }, Cmd.none )

        SetCurrentSession session ->
            let
                oldSessionModel =
                    model.sessionModel

                newSessionModel =
                    { oldSessionModel | currentSession = Maybe.Just session }
            in
                ( { model | sessionModel = newSessionModel }
                , Database.getDatabases session.sessionId
                    |> Cmd.map DatabaseMsg
                )


commandsForRoute : Routing.Route -> Maybe Session.CurrentSession -> Cmd Msg
commandsForRoute route currentSession =
    case route of
        Routing.HomeRoute ->
            Cmd.none

        Routing.DatabasesRoute ->
            case currentSession of
                Maybe.Just { sessionId } ->
                    Database.getDatabases sessionId
                        |> Cmd.map DatabaseMsg

                Maybe.Nothing ->
                    Cmd.none

        Routing.InActiveConnectionsRoute ->
            Cmd.none

        Routing.NewConnectionRoute ->
            Cmd.none

        Routing.NewDatabaseRoute ->
            Cmd.none

        Routing.NotFoundRoute ->
            Cmd.none


header : Model -> Html Msg
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
                [ styles [ Css.paddingLeft (Css.px 16) ] ]
                [ Routing.linkTo Routing.HomeRoute
                    [ styles
                        [ Css.color (Css.hex "#FFFFFF")
                        , Css.textDecoration (Css.none)
                        ]
                    ]
                    [ Html.div
                        [ attribute "main-title" "true"
                        ]
                        [ text "Database manager" ]
                    ]
                ]
            ]
        ]
        |> Html.map RoutingMsg


inActiveSessionsView : Model -> Html Msg
inActiveSessionsView model =
    Html.map SessionMsg
        (model.sessionModel.inActiveDbSessions
            |> Session.sessionListView model.sessionModel
        )


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


openDrawerList : Model -> Html Msg
openDrawerList { sessionModel } =
    let
        list : DbSessions.SessionId -> DbSessions.Connection -> Maybe (List (Html Msg))
        list sessionId connection =
            sessionModel.currentSession
                |> Maybe.map
                    (\cs ->
                        if not (cs.sessionId == sessionId) then
                            [ (drawerItem
                                { iconName = "server"
                                , iconType = Styles.CustomMaterialIcon
                                }
                                (Html.div
                                    [ styles
                                        [ Css.displayFlex
                                        , Css.flexDirection (Css.column)
                                        ]
                                    , Html.Events.onClick (SetCurrentSession (Session.CurrentSession sessionId connection))
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
            ([ Routing.linkTo Routing.NewConnectionRoute
                []
                [ (drawerItem { iconName = "add", iconType = Styles.MaterialIcon }
                    (text "New connection")
                  )
                ]
                |> Html.map RoutingMsg
             ]
                |> List.append
                    (Dict.toList
                        sessionModel.activeDbSessions
                        |> List.filterMap (\( sessionId, connection ) -> list sessionId connection)
                        |> List.concat
                    )
            )


drawer : Html Msg -> Html Msg -> Model -> List (Html Msg)
drawer title subTitle model =
    [ Html.div
        []
        [ drawerHeader title subTitle model
        , Html.div
            [ styles
                [ Css.displayFlex
                , Css.flex (Css.int 1)
                , Css.flexDirection (Css.column)
                ]
            ]
            [ (case model.drawerState of
                DrawerOpen ->
                    openDrawerList model

                DrawerClosed ->
                    closedDrawerList model
              )
            ]
        ]
    ]


drawerItem : Styles.Icon -> Html msg -> Html msg
drawerItem icon item =
    Html.div
        [ styles
            [ Css.padding (Css.px 16)
            , Css.displayFlex
            , Css.displayFlex
            , Css.alignItems (Css.center)
            ]
        ]
        [ Html.span [ styles [ Css.color (Css.rgba 0 0 0 0.54) ] ] [ Styles.fontIcon icon ]
        , Styles.body2
            [ styles [ Css.paddingLeft (Css.px 32) ] ]
            [ item ]
        ]


drawerHeader : Html Msg -> Html Msg -> Model -> Html Msg
drawerHeader title subTitle model =
    let
        titleRow =
            Html.div
                [ styles
                    [ Css.paddingLeft (Css.px 16)
                    , Css.paddingRight (Css.px 16)
                    , Css.paddingBottom (Css.px 16)
                    ]
                ]
                [ Html.div
                    [ styles
                        [ Css.displayFlex
                        , Css.alignItems (Css.center)
                        ]
                    ]
                    [ Html.div
                        [ styles
                            [ Css.displayFlex
                            , Css.flexDirection (Css.column)
                            , Css.flex (Css.int 1)
                            ]
                        ]
                        [ Styles.body2
                            [ styles
                                ([ Css.color (Css.hex "#ffffff")
                                 , Css.lineHeight (Css.initial)
                                 ]
                                    ++ Styles.ellipsis
                                )
                            ]
                            [ title ]
                        , Styles.body2
                            [ styles
                                ([ Css.flex (Css.int 1)
                                 , Css.color (Css.rgba 255 255 255 0.75)
                                 ]
                                    ++ Styles.ellipsis
                                )
                            ]
                            [ subTitle ]
                        ]
                    , Html.div
                        [ styles
                            [ Css.color (Css.hex "#ffffff")
                            ]
                        ]
                        [ Paper.iconButton
                            [ onClick ToggleDrawer
                            , attribute
                                "icon"
                                (case model.drawerState of
                                    DrawerOpen ->
                                        "hardware:keyboard-arrow-up"

                                    DrawerClosed ->
                                        "hardware:keyboard-arrow-down"
                                )
                            ]
                            []
                        ]
                    ]
                ]
    in
        Html.div
            [ styles
                [ Css.backgroundColor (Css.rgb 96 125 139)
                , Css.backgroundSize Css.cover
                ]
            ]
            [ Html.div [ styles [ Css.padding (Css.px 16), Css.paddingTop (Css.px 32) ] ]
                [ Html.div
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
                    [ Styles.fontIcon
                        { iconName = "server"
                        , iconType = Styles.CustomMaterialIcon
                        }
                    ]
                ]
            , titleRow
            ]


closedDrawerList : Model -> Html Msg
closedDrawerList model =
    (Html.div []
        [ Routing.linkTo Routing.DatabasesRoute
            []
            [ drawerItem
                { iconName = "database"
                , iconType = Styles.CustomMaterialIcon
                }
                (text "Databases")
            ]
        , Routing.linkTo Routing.InActiveConnectionsRoute
            []
            [ drawerItem
                { iconName = "server-off"
                , iconType = Styles.CustomMaterialIcon
                }
                (text "Inactive connections")
            ]
        ]
    )
        |> Html.map RoutingMsg


leftDrawer : Model -> Maybe Session.CurrentSession -> Html Msg
leftDrawer model currentSession =
    AppLayout.drawer [ attribute "slot" "drawer" ]
        (Maybe.map
            (\currentSession ->
                drawer
                    (text currentSession.connection.database)
                    (text (Session.connectionString currentSession.connection))
                    model
            )
            currentSession
            |> Maybe.withDefault ([])
        )


notFoundView : Html msg
notFoundView =
    Html.div [] [ text "Not found" ]


viewPage : Model -> Html Msg
viewPage model =
    case model.routingModel.route of
        Routing.HomeRoute ->
            mainView model

        Routing.DatabasesRoute ->
            Database.view model.databaseModel model.sessionModel
                |> Html.map DatabaseMsg

        Routing.InActiveConnectionsRoute ->
            inActiveSessionsView model

        Routing.NewConnectionRoute ->
            Session.connectionFormView model.sessionModel
                |> Html.map SessionMsg

        Routing.NewDatabaseRoute ->
            Session.connectionFormView model.sessionModel
                |> Html.map SessionMsg

        Routing.NotFoundRoute ->
            notFoundView


view : Model -> Html Msg
view model =
    div []
        [ AppLayout.drawerLayout []
            [ leftDrawer model model.sessionModel.currentSession
            , AppLayout.headerLayout []
                [ header model
                , viewPage model
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
