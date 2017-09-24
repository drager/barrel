module Main exposing (..)

import Html exposing (Html, text, div, img, h1)
import Html.Attributes exposing (placeholder, value, class)
import Form exposing (Form)
import Form.Validate as Validate exposing (field, map5, Validation)
import Material
import Material.Button as Button
import Material.Textfield as Textfield
import Material.Options as Options
import Material.Card as Card
import Material.Layout as Layout
import Material.List
import Styles exposing (..)
import Css
import Http
import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Encode as Encode
import Ports exposing (..)
import Utils exposing (..)


type alias DbSessions =
    Dict SessionId Connection


type alias Mdl =
    Material.Model


type alias Connection =
    { host : String
    , portNumber : Int
    , username : String
    , password : String
    , database : String
    }


type alias ConnectionFormData a =
    { a | password : String }


type alias Model =
    { form : Form () Connection
    , mdl : Material.Model
    , dbSessions : DbSessions
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
    | ConnectToDatabase Connection (Result Http.Error SessionId)
    | GetDatabases (Result Http.Error (List Database))
    | ReceiveFromLocalStorage ( String, Decode.Value )


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


connectionEncoder : Connection -> Encode.Value
connectionEncoder connection =
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


connect : Connection -> Http.Request SessionId
connect connection =
    Http.post (getApiUrl ++ "/connect")
        (connectionEncoder connection
            |> Http.jsonBody
        )
        decodeSessionId


getApiUrl : String
getApiUrl =
    "http://localhost:8000"


send : Connection -> Cmd Msg
send connectionInfo =
    Http.send (ConnectToDatabase connectionInfo) (connect connectionInfo)


getDatabases : Cmd Msg
getDatabases =
    Http.send (GetDatabases)
        (Http.get (getApiUrl ++ "/databases") (Decode.list decodeDatabase))


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
    ( { form = Form.initial [] validation
      , mdl = Material.model
      , dbSessions = Dict.empty
      , databases = []
      }
    , Ports.getItemInLocalStorage storageKey
    )


connectionDecoder : Decode.Decoder Connection
connectionDecoder =
    Decode.map5 Connection
        (Decode.field "host" Decode.string)
        (Decode.field "port" Decode.int)
        (Decode.field "username" Decode.string)
        (Decode.field "password" Decode.string)
        (Decode.field "database" Decode.string)


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
                    ( model, send user )

                _ ->
                    ( { model | form = Form.update validation formMsg model.form }, Cmd.none )

        Mdl msg_ ->
            Material.update Mdl msg_ model

        ConnectToDatabase connectionInfo (Ok sessionId) ->
            ( { model | dbSessions = Dict.insert sessionId connectionInfo model.dbSessions }
            , Cmd.batch
                [ pushItemInLocalStorage ( storageKey, (storageEncoder sessionId connectionInfo) )
                , pushItemInSessionStorage ( storageKey, (storageEncoder sessionId connectionInfo) )
                ]
            )

        ConnectToDatabase connectionInfo (Err _) ->
            ( model, Cmd.none )

        ReceiveFromLocalStorage ( storageKey, item ) ->
            case Decode.decodeValue storageDecoder item of
                Ok sessions ->
                    ( { model | dbSessions = sessions }, Cmd.none )

                Err err ->
                    Debug.log err
                        ( model, Cmd.none )

        GetDatabases (Ok databases) ->
            ( { model | databases = databases }, Cmd.none )

        GetDatabases (Err _) ->
            ( model, Cmd.none )


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
                    [ Button.raised, Button.primary, Button.ripple, onSubmit FormMsg ]
                    [ text "Connect" ]
                ]
              -- , Html.button
              --     [ onClick Form.Submit ]
              --     [ text "Connect" ]
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


listDatabasesView : Model -> Html msg
listDatabasesView model =
    div [] []



-- div [] [ Html.map getDatabases ]


sessionListView : List Connection -> Html msg
sessionListView dbSessions =
    div []
        [ Material.List.ul []
            (List.map sessionListItemView dbSessions)
        ]


sessionListItemView : Connection -> Html msg
sessionListItemView dbSession =
    Material.List.li [ Material.List.withSubtitle ]
        [ Material.List.content []
            [ text dbSession.database
            , Material.List.subtitle
                []
                [ text (dbSession.host ++ ":" ++ (dbSession.portNumber |> toString)) ]
            ]
        ]


hasSession : DbSessions -> Bool
hasSession dbSessions =
    Dict.size dbSessions > 0


view : Model -> Html Msg
view model =
    let
        children =
            [ div
                []
                [ if hasSession model.dbSessions then
                    Dict.values model.dbSessions
                        |> sessionListView
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
                [ Layout.fixedHeader, Layout.seamed ]
                { header = header model, drawer = [], main = mainView model children, tabs = ( [], [] ) }
            ]


subscriptions : Model -> Sub Msg
subscriptions model =
    localStorageGetItemResponse ReceiveFromLocalStorage


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
