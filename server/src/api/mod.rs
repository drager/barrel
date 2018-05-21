use actix_web::pred::Predicate;
use actix_web::{
    error, http, AsyncResponder, FutureResponse, HttpMessage, HttpRequest, HttpResponse, Json,
    State,
};
use connection::db::{get_db_session, GetSession};
use connection::pg_connection::{PgDatabaseConnection, PgError};
use connection::{ConnectionData, DatabaseConnection, SessionId};
use futures::future::Future;
use std;
use std::fmt;
use AppState;

extern crate actix_web;
extern crate serde_json;

#[derive(Debug)]
pub enum ApiError {
    InternalError,
    BadClientData,
    Timeout,
    ConnectionRefused,
}

impl fmt::Display for ApiError {
    fn fmt(&self, formatter: &mut fmt::Formatter) -> Result<(), fmt::Error> {
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

#[derive(Debug, Serialize, Deserialize)]
struct ErrorResponse {
    error: String,
}

const X_SESSION_HEADER: &str = "X-Session-Id";

pub struct XSessionHeader;

fn get_session_id_from_request<T>(request: &HttpRequest<T>) -> Option<SessionId> {
    request
        .headers()
        .get(X_SESSION_HEADER)
        .and_then(|id| id.to_str().ok())
        .and_then(|session_id| SessionId::is_valid(session_id).ok())
}

impl<S: 'static> Predicate<S> for XSessionHeader {
    fn check(&self, req: &mut HttpRequest<S>) -> bool {
        get_session_id_from_request(&req.clone()).map_or(false, |_| true)
    }
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

pub fn connect(
    connection_data: Json<ConnectionData>,
    state: State<AppState>,
) -> FutureResponse<HttpResponse> {
    state
        .db
        .send(connection_data.into_inner())
        .from_err()
        .and_then(|res| match res {
            Ok(session) => Ok(HttpResponse::Ok().json(json!({ "session_id": session }))),
            Err(err) => match err {
                PgError::PoolError(_pool_error) => {
                    Ok(create_bad_request_response("Connection refused")?)
                }
                _ => Ok(HttpResponse::InternalServerError().into()),
            },
        })
        .responder()
}

pub fn get_databases(req: HttpRequest<AppState>) -> Result<FutureResponse<HttpResponse>, ApiError> {
    get_session_id_from_request(&req)
        .map(|session_id| {
            req.state()
                .db
                .send(GetSession(session_id))
                .from_err()
                .and_then(move |res| match res {
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
                    }
                })
                .responder()
        })
        .ok_or(ApiError::BadClientData)
}

pub fn connection_retry(
    req: HttpRequest<AppState>,
) -> Result<FutureResponse<HttpResponse>, ApiError> {
    get_session_id_from_request(&req)
        .map(|session_id| {
            req.state()
                .db
                .send(GetSession(session_id))
                .from_err()
                .and_then(move |res| match res {
                    Ok(db_session) => db_session
                        .get()
                        .map_err(|err| actix_web::error::ErrorBadRequest(err))
                        .and_then(|_db_conn| Ok(HttpResponse::Ok().json(session_id))),
                    Err(err) => match err {
                        PgError::NoDbSession => Ok(create_bad_request_response(&format!(
                            "No session could be found with session id: {}",
                            session_id
                        ))?),
                        _ => Ok(HttpResponse::InternalServerError().into()),
                    },
                })
                .responder()
        })
        .ok_or(ApiError::BadClientData)
}

pub fn get_tables(req: HttpRequest<AppState>) -> Result<FutureResponse<HttpResponse>, ApiError> {
    get_session_id_from_request(&req)
        .map(|session_id| {
            get_db_session(session_id, req.state().db.to_owned())
                .map_err(|err| actix_web::error::ErrorBadRequest(err))
                .and_then(move |db_conn| match db_conn {
                    Ok(db_conn) => PgDatabaseConnection::get_tables(db_conn)
                        .map_err(|err| actix_web::error::ErrorBadRequest(err))
                        .map(|tables| HttpResponse::Ok().json(tables)),
                    Err(err) => match err {
                        PgError::NoDbSession => Ok(create_bad_request_response(&format!(
                            "No session could be found with session id: {}",
                            session_id
                        ))?),
                        _ => Ok(HttpResponse::InternalServerError().into()),
                    },
                })
                .responder()
        })
        .ok_or(ApiError::BadClientData)
}
