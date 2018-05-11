extern crate actix;
extern crate actix_web;
extern crate database_manager;
extern crate env_logger;
extern crate futures;
#[macro_use]
extern crate serde_derive;
extern crate serde_json;

use actix::{Addr, Syn, SyncArbiter};
use actix_web::http::header;
use actix_web::pred::Predicate;
use actix_web::server;
use actix_web::{error, http, middleware, test, App, AsyncResponder, Error, FutureResponse,
                HttpMessage, HttpRequest, HttpResponse, Json, Responder, State};
use database_manager::connection::db::{DbExecutor, GetSession};
use database_manager::connection::pg_connection::{PgDatabaseConnection, PgError};
use database_manager::connection::{init_sessions, ConnectionData, DatabaseConnection, SessionId};
use futures::Future;
use std::env;

pub struct AppState {
    db: Addr<Syn, DbExecutor>,
}

#[derive(Debug)]
pub enum ApiError {
    InternalError,
    BadClientData,
    Timeout,
    ConnectionRefused,
}

impl std::fmt::Display for ApiError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter) -> Result<(), std::fmt::Error> {
        write!(formatter, "{}", self)
    }
}

impl std::error::Error for ApiError {
    fn description(&self) -> &str {
        "Api Error"
    }
}

impl error::ResponseError for ApiError {
    fn error_response(&self) -> HttpResponse {
        match *self {
            ApiError::InternalError => HttpResponse::new(http::StatusCode::INTERNAL_SERVER_ERROR),
            ApiError::BadClientData => HttpResponse::new(http::StatusCode::BAD_REQUEST),
            ApiError::Timeout => HttpResponse::new(http::StatusCode::GATEWAY_TIMEOUT),
            ApiError::ConnectionRefused => {
                HttpResponse::with_body(http::StatusCode::BAD_REQUEST, "json_err")
            }
        }
    }
}

const X_SESSION_HEADER: &str = "X-Session-Id";

struct XSessionHeader;

fn get_session_id_from_request<T>(request: &HttpRequest<T>) -> Option<SessionId> {
    request
        .headers()
        .get(X_SESSION_HEADER)
        .and_then(|id| id.to_str().ok())
        .and_then(|session_id| SessionId::is_valid(session_id).ok())
}

impl<S: 'static> Predicate<S> for XSessionHeader {
    fn check(&self, req: &mut HttpRequest<S>) -> bool {
        println!("req {:?}", req);

        let valid = get_session_id_from_request(&req.clone()).map_or(false, |_| true);
        println!("valid: {}", valid);
        valid
        // req.headers().contains_key("X-Session-Id")
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Database {
    pub name: String,
    pub oid: u32,
}

impl Responder for Database {
    type Item = HttpResponse;
    type Error = Error;

    fn respond_to(self, _req: HttpRequest) -> Result<Self::Item, Error> {
        let body = serde_json::to_string(&self)?;

        Ok(HttpResponse::Ok()
            .content_type("application/json")
            .body(body))
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct ErrorResponse {
    error: String,
}

fn create_bad_request_response(error_msg: &str) -> Result<HttpResponse, serde_json::Error> {
    let body = serde_json::to_string(&ErrorResponse {
        error: error_msg.to_string(),
    })?;
    let response = HttpResponse::BadRequest()
        .content_type("application/json")
        .body(body);
    Ok(response)
}

fn connect(
    connection_data: Json<ConnectionData>,
    state: State<AppState>,
) -> FutureResponse<HttpResponse> {
    let connection_data: ConnectionData = connection_data.into_inner();
    let a = state
        .db
        .send(connection_data)
        .from_err()
        .and_then(|res| match res {
            Ok(session) => Ok(HttpResponse::Ok().json(session)),
            Err(err) => {
                println!("wop wop err {:?}", err);
                match err {
                    PgError::PoolError(_pool_error) => {
                        Ok(create_bad_request_response("Connection refused")?)
                    }
                    _ => Ok(HttpResponse::InternalServerError().into()),
                }
            }
        });
    a.responder()
    // state.db.send(SessionId).responder()
    // state.db
    // let result: Result<Json<Database>, SError> = Ok(database);
    // let a = Ok(result.map_err(|err| actix_web::error::ErrorBadRequest(err))?);
    // HttpResponse::Ok().into()
}

pub fn get_databases(
    req: HttpRequest<AppState> // state: State, // session_id: Json<SessionId>, // state: State<AppState>
) -> FutureResponse<HttpResponse> {
    get_session_id_from_request(&req)
        .map(|session_id| {
            println!("GET SESS {:?}", session_id);
            let future = req.state()
                .db
                .send(GetSession(session_id))
                .from_err()
                .and_then(move |res| {
                    match res {
                        Ok(db_session) => db_session
                            .get()
                            .map_err(|err| actix_web::error::ErrorBadRequest(err))
                            .and_then(|db_conn| {
                                PgDatabaseConnection::get_databases(db_conn)
                                    .map_err(|err| actix_web::error::ErrorBadRequest(err))
                                    .map(|databases| HttpResponse::Ok().json(databases))
                            }),
                        Err(err) => {
                            println!("Err in match {:?}", err);
                            match err {
                                PgError::NoDbSession => Ok(create_bad_request_response(&format!(
                                    "No session could be found with session id: {}",
                                    session_id
                                ))?),
                                _ => Ok(HttpResponse::InternalServerError().into()),
                            }
                            // Ok(HttpResponse::InternalServerError().into())
                        }
                    }
                    // let c = match res {
                    //     Ok(db_session) => db_session.get().map(|db_conn| {
                    //         PgDatabaseConnection::get_databases(db_conn)
                    //             .map(|databases| HttpResponse::Ok().json(databases))
                    //     }),
                    //     Err(err) => Ok(actix_web::error::ErrorBadRequest(err)),
                    // };
                    // let result: Result<HttpResponse, actix_web::error::Error> =
                    //     Ok(HttpResponse::InternalServerError().into());
                    // result
                });
            // let future = req.state()
            //     .db
            //     .send(GetSession(session_id))
            //     .from_err()
            //     .and_then(|res| match res {
            //         Ok(db_session) => match db_session.get() {
            //             Ok(db_conn) => PgDatabaseConnection::get_databases(db_conn)
            //                 .map(|databases| HttpResponse::Ok().json(databases)),

            //             Err(err) => Ok(HttpResponse::InternalServerError().into()),
            //         },
            //         Err(err) => Ok(HttpResponse::InternalServerError().into()),
            //     })
            //     .responder();

            future.responder()
            // println!("S: {:?}", s);
        })
        .unwrap()
    // println!("req in route {:?}", req);
    // println!("session_id in route {:?}", session_id);
    // println!("session id {:?}", session_id);
    // let a = state.db;
    // let a = state
    //     .db
    //     .send(GetSession(session_id))
    //     .from_err()
    //     .and_then(|res| res)
    //     .responder();
    // Ok(Json(vec![]))
    // db_sessions
    //     .get(&*session_id)
    //     .ok_or(ApiError::NoDbSession)
    //     .and_then(|db_session| match db_session.get() {
    //         Ok(db_conn) => PgDatabaseConnection::get_databases(db_conn)
    //             .map(Json)
    //             .map_err(ApiError::from),
    //         Err(_) => Err(ApiError::NoDbSession),
    //     })
}

fn main() {
    env::set_var("RUST_LOG", "actix_web=info");
    env_logger::init();

    let sys = actix::System::new("barrel");

    let sessions = init_sessions();
    let addr = SyncArbiter::start(3, move || DbExecutor(sessions.clone()));

    server::new(move || {
        App::with_state(AppState { db: addr.clone() })
            .middleware(middleware::Logger::default())
            .resource("/connect", |r| r.route().with2(connect))
            .resource("/databases", |r| {
                r.route().filter(XSessionHeader).f(get_databases)
            })
    }).bind("127.0.0.1:8000")
        .unwrap()
        .start();

    println!("Started server at: 127.0.0.1:8000");

    let _ = sys.run();

    // HttpServer::new(|| App::new().resource("/", |r| r.route().filter(XSessionHeader).with(index)))
    //     .bind("127.0.0.1:8000")
    //     .unwrap()
    //     .start();

    // let _ = sys.run();

    // let test_db = Json(Database {
    //     name: "asd".to_owned(),
    //     oid: 1,
    // });

    // let resp = test::TestRequest::default().run(index(test_db)).unwrap();
    // assert_eq!(resp.status(), http::StatusCode::OK);
}

// fn main() {
//     let (allowed_origins, failed_origins) =
//         AllowedOrigins::some(&["http://localhost:3000", "http://127.0.0.1:3000"]);
//     assert!(failed_origins.is_empty());

//     // You can also deserialize this
//     let options = rocket_cors::Cors {
//         allowed_origins: allowed_origins,
//         allowed_methods: vec![Method::Get, Method::Post]
//             .into_iter()
//             .map(From::from)
//             .collect(),
//         allowed_headers: AllowedHeaders::all(),
//         allow_credentials: true,
//         ..Default::default()
//     };

//     rocket::ignite()
//         .mount(
//             "/",
//             routes![
//                 api::connect,
//                 api::get_databases,
//                 api::connection_retry,
//                 api::get_tables
//             ],
//         )
//         .manage(init_sessions())
//         .attach(options)
//         .launch();
// }
