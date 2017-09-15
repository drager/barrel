use rocket::State;
use rocket_contrib::Json;
use connection::DatabaseConnection;
use connection::pg_connection::PgDatabaseConnection;
use postgres::params::ConnectParams;
use postgres::params::Host;
use postgres;
use rocket::{response, Request};
use api::db_pool::DatabasePooledConnection;
use api::db_pool::DbConnection;

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
}

#[derive(Debug, Serialize, Deserialize)]
enum Status {
    Ok,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Database {
    name: String,
    owner: String,
    oid: u32,
}

#[post("/connect", data = "<connection_information>")]
pub fn connect(connection_information: Json<ConnectionInformation>,
               db_conn: DbConnection)
               -> Result<Json<ConnectionResponse>, ApiError> {
    let params = ConnectParams::builder()
        .port(connection_information.port)
        .user(&connection_information.username,
              Some(&connection_information.password))
        .database(&connection_information.database)
        .build(Host::Tcp(connection_information.host.to_owned()));

    Ok(PgDatabaseConnection::init_db_pool(params)
           .map(|connection| {
                    use std::sync::RwLock;
                    // let mut write_lock = db_conn.write().unwrap();
                    // *write_lock = Some(RwLock::new(Some(connection)));
                    Json(ConnectionResponse { status: Status::Ok })
                })?)
}

#[get("/databases")]
pub fn get_databases(db_conn: DbConnection) -> Result<Json<Vec<Database>>, ApiError> {
    // db_conn
    //     .inner()
    //     .pool
    //     .read()
    //     .map(|connection| {
    //         connection.unwrap().get().execute("", &[&"1"]);
    //         Ok(vec![Database {
    //                     name: "postgres".to_owned(),
    //                     owner: "postgres".to_owned(),
    //                     oid: 123,
    //                 }])
    //                 .map(Json)
    //     })
    // println!("DB CONN {:?}", db_conn);

    Ok(vec![Database {
                name: "postgres".to_owned(),
                owner: "postgres".to_owned(),
                oid: 123,
            }])
            .map(Json)
}

pub fn json_error(reason: &str) -> Json {
    Json(json!({
        "status": "error",
        "reason": reason,
    }))
}

#[derive(Debug)]
pub enum ApiError {
    PostgresError(postgres::Error),
}

impl From<postgres::Error> for ApiError {
    fn from(err: postgres::Error) -> ApiError {
        ApiError::PostgresError(err)
    }
}

impl<'a> response::Responder<'a> for ApiError {
    fn respond_to(self, request: &Request) -> response::Result<'a> {
        println!("self {:?}", self);
        Json(json!({"message": "failure"})).respond_to(request)
    }
}
