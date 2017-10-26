module Drawer exposing (..)

import Html exposing (Html)
import Html.Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Styles exposing (styles)
import Css
import WebComponents.Paper as Paper


type Msg
    = ToggleDrawer


type DrawerState
    = DrawerOpen
    | DrawerClosed


type alias Model =
    { drawerState : DrawerState }


init : ( Model, Cmd Msg )
init =
    ( { drawerState = DrawerClosed }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
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


drawerItem : Styles.Icon -> String -> Html msg
drawerItem icon itemText =
    Html.div
        [ styles
            [ Css.padding (Css.px 16)
            , Css.displayFlex
            , Css.displayFlex
            , Css.alignItems (Css.center)
            ]
        ]
        [ Html.span [ styles [ Css.color (Css.rgba 0 0 0 0.54) ] ] [ Styles.fontIcon icon ]
        , Html.span [ styles [ Css.paddingLeft (Css.px 32) ] ]
            [ Html.text itemText ]
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
                [ Html.span
                    [ styles
                        ([ Css.color (Css.hex "#ffffff") ]
                            ++ Styles.ellipsis
                        )
                    ]
                    [ title ]
                , Html.div [ styles [ Css.displayFlex, Css.alignItems (Css.center) ] ]
                    [ Html.div
                        [ styles
                            ([ Css.flex (Css.int 1)
                             , Css.color (Css.hex "#ffffff")
                             ]
                                ++ Styles.ellipsis
                            )
                        ]
                        [ subTitle ]
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


type alias DrawerAttributes =
    { title : Html Msg
    , subTitle : Html Msg
    , model : Model
    , openDrawerList : Html Msg
    , closedDrawerList : Html Msg
    }


drawer : DrawerAttributes -> List (Html Msg)
drawer { title, subTitle, model, openDrawerList, closedDrawerList } =
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
                    openDrawerList

                DrawerClosed ->
                    closedDrawerList
              )
            ]
        ]
    ]
