#![feature(plugin)]
#![plugin(rocket_codegen)]

extern crate rocket;
extern crate postgres;
extern crate database_manager;
extern crate rocket_contrib;
extern crate serde;
extern crate serde_json;
#[macro_use]
extern crate serde_derive;

use rocket_contrib::Json;
use database_manager::connection::DatabaseConnection;
use database_manager::connection::pg_connection::PgDatabaseConnection;
use postgres::params::ConnectParams;
use postgres::params::Host;

#[derive(Serialize, Deserialize)]
struct ConnectionInformation {
    host: String,
    port: u16,
    username: String,
    password: String,
    database: String,
}

#[post("/connect", data = "<connection_information>")]
fn connect(connection_information: Json<ConnectionInformation>)
           -> Result<Json<ConnectionInformation>, postgres::Error> {
    let params = ConnectParams::builder()
        .port(connection_information.port)
        .user(&connection_information.username,
              Some(&connection_information.password))
        .database(&connection_information.database)
        .build(Host::Tcp(connection_information.host.to_owned()));
    PgDatabaseConnection::connect(params)
        .map(|connection| connection_information)
        .map_err()
    // "postgres://postgres@localhost:5433"
    // Json(connection.unwrap())
}

fn main() {
    rocket::ignite().mount("/", routes![connect]).launch();
}