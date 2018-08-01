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
use api::{connect, get_databases, get_tables, XSessionHeader};
use connection::db::DbExecutor;

pub mod api;
pub mod connection;

pub struct AppState {
    pub db: Addr<Syn, DbExecutor>,
}

pub fn create_app(app_state: AppState) -> actix_web::App<AppState> {
    actix_web::App::with_state(app_state)
        .middleware(actix_web::middleware::cors::Cors::default())
        .middleware(actix_web::middleware::Logger::default())
        .resource("/connect", |r| r.route().with2(connect))
        .resource("/databases", |r| {
            r.route().filter(XSessionHeader).f(get_databases)
        })
        .resource("/databases/{database_name}/tables", |r| {
            r.route().filter(XSessionHeader).with(get_tables)
        })
}

#[cfg(test)]
mod tests {
    extern crate actix;
    extern crate actix_web;

    use api::get_databases;
    use api::X_SESSION_HEADER;
    use connection::db::DbExecutor;
    use connection::init_sessions;
    use connection::SessionId;
    use create_app;
    use AppState;

    #[test]
    fn it_works() {
        let mut server = actix_web::test::TestServer::with_factory(move || {
            let sessions = init_sessions();
            let addr = actix::SyncArbiter::start(3, move || DbExecutor(sessions.clone()));
            let state = AppState { db: addr };
            create_app(state)
        });

        let request = server
            .client(actix_web::http::Method::GET, "/databases")
            .set_header(X_SESSION_HEADER, SessionId::new().to_string())
            .finish()
            .unwrap();

        let response = server.execute(request.send()).unwrap();

        assert_eq!(response.status(), actix_web::http::StatusCode::BAD_REQUEST);

        // let resp = actix_web::test::TestRequest::with_state(server)
        //     .run(get_databases)
        //     .unwrap();
        // assert_eq!(resp.status(), actix_web::http::StatusCode::OK);
    }
}
