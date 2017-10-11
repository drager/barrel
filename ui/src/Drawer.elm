module Drawer exposing (..)

import Html exposing (Html)
import Styles exposing (styles)
import Material
import Material.Typography
import Material.Options
import Material.Button
import Css


type Msg
    = Mdl (Material.Msg Msg)
    | OpenDrawer
    | CloseDrawer


type DrawerState
    = DrawerOpen
    | DrawerClosed


type alias Model =
    { drawerState : DrawerState, mdl : Material.Model }


init : ( Model, Cmd Msg )
init =
    ( { drawerState = DrawerClosed, mdl = Material.model }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Mdl msg_ ->
            Material.update Mdl msg_ model

        OpenDrawer ->
            ( { model | drawerState = DrawerOpen }, Cmd.none )

        CloseDrawer ->
            ( { model | drawerState = DrawerClosed }, Cmd.none )


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
            [ Material.Options.styled
                Html.span
                [ Material.Typography.body2 ]
                [ Html.text itemText ]
            ]
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
                [ Html.span [ styles [ Css.color (Css.hex "#ffffff") ] ]
                    [ Material.Options.styled
                        Html.span
                        [ Material.Typography.body2 ]
                        [ title ]
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
                            [ subTitle ]
                        ]
                    , Html.div
                        [ styles
                            [ Css.color (Css.hex "#ffffff")
                            ]
                        ]
                        [ Material.Button.render Mdl
                            [ 0 ]
                            model.mdl
                            [ Material.Button.icon
                            , Material.Options.onClick OpenDrawer
                            ]
                            [ Styles.fontIcon
                                { iconName =
                                    (case model.drawerState of
                                        DrawerOpen ->
                                            "keyboard_arrow_up"

                                        DrawerClosed ->
                                            "keyboard_arrow_down"
                                    )
                                , iconType = Styles.MaterialIcon
                                }
                            ]
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
            [ drawerItem
                { iconName = "server"
                , iconType = Styles.CustomMaterialIcon
                }
                "Active connections"
            , drawerItem
                { iconName = "server-off"
                , iconType = Styles.CustomMaterialIcon
                }
                "Inactive connections"
            ]
        ]
    ]
