// use diesel::pg::PgConnection;
use r2d2;
use postgres::Connection;
use r2d2_postgres::{PostgresConnectionManager, TlsMode};
use rocket::{Outcome, Request, State};
use rocket::http::Status;
use rocket::request::{self, FromRequest};
use std::ops::Deref;
use std::sync::RwLock;

#[derive(Debug)]
pub struct DatabasePooledConnection {
    pub pool: RwLock<Option<Pool>>,
}

pub fn init_pool() -> Pool {
    RwLock::new(None)
}

// An alias to the type for a pool of Diesel Postgresql connections.
pub type Pool = RwLock<Option<r2d2::Pool<PostgresConnectionManager>>>;

// Connection request guard type: a wrapper around an r2d2 pooled connection.
pub struct DbConnection(pub r2d2::PooledConnection<PostgresConnectionManager>);
/// Attempts to retrieve a single connection from the managed database pool. If
/// no pool is currently managed, fails with an `InternalServerError` status. If
/// no connections are available, fails with a `ServiceUnavailable` status.
impl<'a, 'r> FromRequest<'a, 'r> for DbConnection {
    type Error = ();

    fn from_request(request: &'a Request<'r>) -> request::Outcome<DbConnection, ()> {
        let rw = request.guard::<State<Pool>>()?;

        // match rw.read().unwrap() {
        //     Ok(pool_option) => {
        //         match pool_option {
        //             Some(pool) => {
        //                 match pool.get() {
        //                     Ok(conn) => Outcome::Success(DbConnection(conn)),
        //                     Err(_) => Outcome::Failure((Status::ServiceUnavailable, ())),
        //                 }
        //             }
        //             None(_) => Outcome::Failure((Status::ServiceUnavailable, ())),
        //         }
        //     }
        //     Err(_) => Outcome::Failure((Status::ServiceUnavailable, ())),
        // }

        let read_lock = rw.read()
            .unwrap()
            .clone()
            .map(|pool| match pool.get() {
                     Ok(conn) => Outcome::Success(DbConnection(conn)),
                     Err(_) => Outcome::Failure((Status::ServiceUnavailable, ())),
                 });

        match read_lock {
            Some(conn) => conn,
            None => Outcome::Failure((Status::ServiceUnavailable, ())),
        }
        // read_lock
        //     .map(|conn| conn)
        //     .ok_or(Outcome::Failure((Status::ServiceUnavailable, ())))
        //     .map(|x| x)
        // .ok_or(Outcome::Failure((Status::ServiceUnavailable, ())));
        // let read_lock = match read_lock {
        //     Ok(c) => c,
        //     Err(_) => Outcome::Failure((Status::ServiceUnavailable, ())),
        // };
        // .unwrap();
        //      })
        // .map_err(|_| Outcome::Failure((Status::ServiceUnavailable, ())));
        // .unwrap();
        // read_lock.unwrap()
    }
}
