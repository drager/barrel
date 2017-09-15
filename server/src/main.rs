#![feature(plugin)]
#![plugin(rocket_codegen)]

extern crate rocket;
extern crate database_manager;

use database_manager::api;
use database_manager::api::db_pool::{DatabasePooledConnection, DbConnection, Pool, init_pool};
use std::sync::RwLock;

fn main() {
    rocket::ignite()
        .mount("/", routes![api::connect, api::get_databases])
        .manage(init_pool())
        .launch();
}
