#![feature(plugin)]
#![plugin(rocket_codegen)]

extern crate rocket;
extern crate database_manager;

use database_manager::api;
use database_manager::api::db_pool::init_sessions;

fn main() {
    rocket::ignite()
        .mount("/", routes![api::connect, api::get_databases])
        .manage(init_sessions())
        .launch();
}
 