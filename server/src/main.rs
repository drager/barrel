extern crate actix;
extern crate actix_web;
extern crate database_manager;
extern crate env_logger;
extern crate futures;
extern crate serde_json;

use database_manager::connection::db::DbExecutor;
use database_manager::connection::init_sessions;
use database_manager::{create_app, AppState};
use std::env;

fn main() {
    env::set_var("RUST_LOG", "actix_web=info");
    env_logger::init();

    let sys = actix::System::new("barrel");

    let sessions = init_sessions();
    let addr = actix::SyncArbiter::start(3, move || DbExecutor(sessions.clone()));

    actix_web::server::new(move || create_app(AppState { db: addr.clone() }))
        .bind("127.0.0.1:8000")
        .unwrap()
        .start();

    println!("Started server at: 127.0.0.1:8000");

    let _ = sys.run();
}
