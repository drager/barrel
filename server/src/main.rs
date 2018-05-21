extern crate actix;
extern crate actix_web;
extern crate database_manager;
extern crate env_logger;
extern crate futures;
extern crate serde_json;

use database_manager::api::{connect, get_databases, get_tables, XSessionHeader};
use database_manager::connection::db::DbExecutor;
use database_manager::connection::init_sessions;
use database_manager::AppState;
use std::env;

fn main() {
    env::set_var("RUST_LOG", "actix_web=info");
    env_logger::init();

    let sys = actix::System::new("barrel");

    let sessions = init_sessions();
    let addr = actix::SyncArbiter::start(3, move || DbExecutor(sessions.clone()));

    actix_web::server::new(move || {
        actix_web::App::with_state(AppState { db: addr.clone() })
            .middleware(actix_web::middleware::cors::Cors::default())
            .middleware(actix_web::middleware::Logger::default())
            .resource("/connect", |r| r.route().with2(connect))
            .resource("/databases", |r| {
                r.route().filter(XSessionHeader).f(get_databases)
            })
            .resource("/databases/{database_name}/tables", |r| {
                r.route().filter(XSessionHeader).with(get_tables)
            })
    }).bind("127.0.0.1:8000")
        .unwrap()
        .start();

    println!("Started server at: 127.0.0.1:8000");

    let _ = sys.run();
}
