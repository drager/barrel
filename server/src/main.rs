#![feature(plugin)]
#![plugin(rocket_codegen)]

extern crate rocket;
extern crate database_manager;
extern crate rocket_cors;

use database_manager::api;
use database_manager::api::db_pool::init_sessions;
use rocket_cors::{AllowedOrigins, AllowedHeaders};
use rocket::http::Method;

fn main() {
    let (allowed_origins, failed_origins) = AllowedOrigins::some(&["http://localhost:3000",
                                                                   "http://127.0.0.1:3000"]);
    assert!(failed_origins.is_empty());

    // You can also deserialize this
    let options = rocket_cors::Cors {
        allowed_origins: allowed_origins,
        allowed_methods: vec![Method::Get, Method::Post]
            .into_iter()
            .map(From::from)
            .collect(),
        allowed_headers: AllowedHeaders::all(),
        allow_credentials: true,
        ..Default::default()
    };

    rocket::ignite()
        .mount("/", routes![api::connect, api::get_databases])
        .manage(init_sessions())
        .attach(options)
        .launch();
}