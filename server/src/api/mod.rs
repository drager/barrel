use rocket::State;
use rocket_contrib::Json;
use connection::DatabaseConnection;
use connection::pg_connection::PgDatabaseConnection;
use postgres::params::ConnectParams;
use postgres::params::Host;
use postgres;
use rocket::{response, Request};
use api::db_pool::{DbSessions, LockedSession, SessionId};
use connection::{pg_connection, Database};
use uuid::Uuid;
use std::sync::{RwLock, PoisonError};

pub mod db_pool;

#[derive(Serialize, Deserialize)]
pub struct ConnectionInformation {
    host: String,
    port: u16,
    username: String,
    password: String,
    database: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ConnectionResponse {
    status: Status,
    session_id: Uuid,
}

#[derive(Debug, Serialize, Deserialize)]
enum Status {
    Ok,
}

#[post("/connect", data = "<connection_information>")]
pub fn connect(connection_information: Json<ConnectionInformation>,
               state_session: State<LockedSession>)
               -> Result<Json<ConnectionResponse>, ApiError> {
    let params = ConnectParams::builder()
        .port(connection_information.port)
        .user(&connection_information.username,
              Some(&connection_information.password))
        .database(&connection_information.database)
        .build(Host::Tcp(connection_information.host.to_owned()));

    PgDatabaseConnection::init_db_pool(params)
        .map_err(ApiError::from)
        .map(|connection| {
            println!("state_session: {:?}", state_session);

            match state_session.write() {
                Ok(mut session) => {
                    println!("session: {:?}", session);
                    let session_id = Uuid::new_v4();
                    session.add(session_id, connection);
                    Ok(Json(ConnectionResponse {
                                status: Status::Ok,
                                session_id: session_id,
                            }))
                }
                Err(_) => Err(ApiError::CouldNotWriteDbSession),
            }
        })?
}

#[post("/connection/retry", data = "<session_id>")]
pub fn connection_retry(session_id: Json<SessionId>,
                        db_sessions: DbSessions)
                        -> Result<Json<ConnectionResponse>, ApiError> {
    // TODO: Break this out into a function? Maybe on the Struct?
    db_sessions
        .get(&*session_id)
        .ok_or(ApiError::NoDbSession)
        .and_then(|db_session| match db_session.get() {
                      Ok(_db_conn) => {
                          Ok(Json(ConnectionResponse {
                                      session_id: session_id.clone(),
                                      status: Status::Ok,
                                  }))
                      }
                      Err(_) => Err(ApiError::NoDbSession),
                  })
}

#[get("/databases")]
pub fn get_databases(session_id: SessionId,
                     db_sessions: DbSessions)
                     -> Result<Json<Vec<Database>>, ApiError> {
    db_sessions
        .get(&*session_id)
        .ok_or(ApiError::NoDbSession)
        .and_then(|db_session| match db_session.get() {
                      Ok(db_conn) => {
                          PgDatabaseConnection::get_databases(db_conn)
                              .map(Json)
                              .map_err(ApiError::from)
                      }
                      Err(_) => Err(ApiError::NoDbSession),
                  })
}

pub fn json_error(reason: &str) -> Json {
    Json(json!({
        "status": "error",
        "reason": reason,
    }))
}

type LockedSessionPoisionError = PoisonError<RwLock<DbSessions>>;

#[derive(Debug)]
pub enum ApiError {
    PostgresError(pg_connection::PgError),
    QueryError(postgres::Error),
    LockedSessionError(LockedSessionPoisionError),
    StringError(String),
    NoDbSession,
    CouldNotWriteDbSession,
}

impl From<pg_connection::PgError> for ApiError {
    fn from(err: pg_connection::PgError) -> ApiError {
        ApiError::PostgresError(err)
    }
}

impl From<LockedSessionPoisionError> for ApiError {
    fn from(err: LockedSessionPoisionError) -> ApiError {
        ApiError::LockedSessionError(err)
    }
}

impl From<String> for ApiError {
    fn from(err: String) -> ApiError {
        ApiError::StringError(err)
    }
}

impl From<postgres::Error> for ApiError {
    fn from(err: postgres::Error) -> ApiError {
        ApiError::QueryError(err)
    }
}

impl<'a> response::Responder<'a> for ApiError {
    fn respond_to(self, request: &Request) -> response::Result<'a> {
        println!("self {:?}", self);
        Json(json!({"message": "failure"})).respond_to(request)
    }
}
