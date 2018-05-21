extern crate actix;
extern crate actix_web;
extern crate futures;
extern crate postgres;
extern crate r2d2;
extern crate r2d2_postgres;
#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate serde_json;
extern crate uuid;

use actix::{Addr, Syn};
use connection::db::DbExecutor;

pub mod api;
pub mod connection;

pub struct AppState {
    pub db: Addr<Syn, DbExecutor>,
}

#[cfg(test)]
mod tests {
    extern crate actix;
    extern crate actix_web;

    use api::get_databases;
    use connection::db::DbExecutor;
    use connection::init_sessions;
    use AppState;

    #[test]
    fn it_works() {
        let sessions = init_sessions();
        let addr = actix::SyncArbiter::start(3, move || DbExecutor(sessions.clone()));

        let state = AppState { db: addr.clone() };

        let resp = actix_web::test::TestRequest::with_state(state)
            .run(get_databases)
            .unwrap();
        assert_eq!(resp.status(), actix_web::http::StatusCode::OK);
    }
}
