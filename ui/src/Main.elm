module Main exposing (..)

import Html exposing (Html, text, div, img)
import Html.Attributes exposing (placeholder, value, class)
import Html.Events exposing (onClick)
import Form exposing (Form)
import Form.Validate as Validate exposing (field, map5, Validation)
import Form.Field
import Form.Input as Input
import Material
import Material.Button as Button
import Material.Textfield as Textfield
import Material.Options as Options
import Material.Card as Card
import Material.Color as Color
import Material.Layout as Layout
import Styles exposing (..)
import Css


type alias Mdl =
    Material.Model


type alias Connection =
    { host : String
    , portNumber : Int
    , username : String
    , password : String
    , database : String
    }


type alias Model =
    { form : Form () Connection, mdl : Material.Model }


validation : Validation () Connection
validation =
    map5 Connection
        (field "host" Validate.string)
        (field "portNumber" Validate.int)
        (field "username" Validate.string)
        (field "password" Validate.string)
        (field "database" Validate.string)


init : ( Model, Cmd Msg )
init =
    ( { form = Form.initial [] validation, mdl = Material.model }, Cmd.none )



---- UPDATE ----


type Msg
    = FormMsg Form.Msg
    | Mdl (Material.Msg Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ form } as model) =
    case msg of
        FormMsg formMsg ->
            ( { model | form = Form.update validation formMsg form }, Cmd.none )

        Mdl msg_ ->
            Material.update Mdl msg_ model


connectionFormView : Model -> Html Msg
connectionFormView model =
    let
        -- error presenter
        errorFor field =
            case field.liveError of
                Just error ->
                    -- replace toString with your own translations
                    div [ class "error" ] [ text (toString error) ]

                Nothing ->
                    text ""

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
    in
        Card.view []
            [ cardBlock
                [ Textfield.render
                    Mdl
                    [ 0 ]
                    model.mdl
                    [ Textfield.label "Host"
                    , Textfield.floatingLabel
                    , Textfield.text_
                    , Textfield.value <| Maybe.withDefault "" host.value
                    , onMaterialInput FormMsg host.path
                    , onMaterialFocus FormMsg host.path
                    , onMaterialBlur FormMsg host.path
                    ]
                    []
                , Textfield.render
                    Mdl
                    [ 1 ]
                    model.mdl
                    [ Textfield.label "Port"
                    , Textfield.floatingLabel
                    , Textfield.text_
                    , Textfield.value <| Maybe.withDefault "" portNumber.value
                    , onMaterialInput FormMsg portNumber.path
                    , onMaterialFocus FormMsg portNumber.path
                    , onMaterialBlur FormMsg portNumber.path
                    ]
                    []
                , Textfield.render
                    Mdl
                    [ 2 ]
                    model.mdl
                    [ Textfield.label "Username"
                    , Textfield.floatingLabel
                    , Textfield.text_
                    , Textfield.value <| Maybe.withDefault "" username.value
                    , onMaterialInput FormMsg username.path
                    , onMaterialFocus FormMsg username.path
                    , onMaterialBlur FormMsg username.path
                    ]
                    []
                , Textfield.render
                    Mdl
                    [ 3 ]
                    model.mdl
                    [ Textfield.label "Password"
                    , Textfield.floatingLabel
                    , Textfield.password
                    , Textfield.value <| Maybe.withDefault "" password.value
                    , onMaterialInput FormMsg password.path
                    , onMaterialFocus FormMsg password.path
                    , onMaterialBlur FormMsg password.path
                    ]
                    []
                , Textfield.render
                    Mdl
                    [ 4 ]
                    model.mdl
                    [ Textfield.label "Database"
                    , Textfield.floatingLabel
                    , Textfield.text_
                    , Textfield.value <| Maybe.withDefault "" database.value
                    , onMaterialInput FormMsg database.path
                    , onMaterialFocus FormMsg database.path
                    , onMaterialBlur FormMsg database.path
                    , Options.attribute <| Html.Attributes.type_ "number"
                    ]
                    [ Options.attribute <| Html.Attributes.type_ "number" ]
                  -- , Html.label
                  --     []
                  --     [ text "Port" ]
                  -- , Input.textInput portNumber []
                  -- , errorFor portNumber
                  -- , Html.label
                  --     []
                  --     [ text "Username" ]
                  -- , Input.textInput username []
                  -- , errorFor username
                  -- , Html.label
                  --     []
                  --     [ text "Password" ]
                  -- , Input.textInput password []
                  -- , errorFor password
                  -- , Html.label
                  --     []
                  --     [ text "Database" ]
                  -- , Input.textInput database []
                  -- , errorFor database
                ]
            , Card.actions []
                [ Button.render Mdl
                    [ 5 ]
                    model.mdl
                    [ Button.raised, Button.primary, Button.ripple ]
                    [ text "Connect" ]
                ]
              -- , Html.button
              --     [ onClick Form.Submit ]
              --     [ text "Connect" ]
            ]


onMaterialInput : (Form.Msg -> msg) -> String -> Options.Property c msg
onMaterialInput msg path =
    Options.onInput <| msg << Form.Input path Form.Text << Form.Field.String


onMaterialFocus : (Form.Msg -> msg) -> String -> Options.Property c msg
onMaterialFocus msg path =
    Options.onFocus << msg <| Form.Focus path


onMaterialBlur : (Form.Msg -> msg) -> String -> Options.Property c msg
onMaterialBlur msg path =
    Options.onBlur << msg <| Form.Blur path


header : Model -> List (Html Msg)
header model =
    [ Layout.row
        []
        [ Layout.title [] [ text "Database manager" ]
        ]
    ]


mainView : Model -> List (Html Msg) -> List (Html Msg)
mainView model children =
    [ div [ styles [ Css.displayFlex, Css.paddingTop (Css.px 32.0) ] ] children ]


view : Model -> Html Msg
view model =
    let
        children =
            [ div [ styles [ Css.displayFlex, Css.flexDirection Css.column, Css.alignItems Css.center, Css.flex (Css.int 1) ] ] [ connectionFormView model ] ]
    in
        div []
            [ Layout.render Mdl
                model.mdl
                [ Layout.fixedHeader, Layout.seamed ]
                { header = header model, drawer = [], main = mainView model children, tabs = ( [], [] ) }
            ]


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }
