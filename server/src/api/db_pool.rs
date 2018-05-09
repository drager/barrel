// use r2d2;
// use r2d2_postgres::PostgresConnectionManager;
// use rocket::{Outcome, Request, State};
// use rocket::http::Status;
// use rocket::request::{self, FromRequest};
// use std::collections::HashMap;
// use std::ops::Deref;
// use std::sync::RwLock;
// use uuid::{self, Uuid};

// impl DbSessions {
//     pub fn add(&mut self, session_id: Uuid, db_conn: Pool) -> Option<Pool> {
//         self.0.insert(session_id, db_conn)
//     }

//     pub fn get<'a>(&'a self, session_id: &'a Uuid) -> Option<&'a Pool> {
//         self.0.get(session_id)
//     }
// }

// pub type LockedSession = RwLock<DbSessions>;

// pub fn init_sessions() -> LockedSession {
//     RwLock::new(DbSessions(HashMap::new()))
// }

// #[derive(Debug, Clone)]
// pub struct DbSessions(HashMap<Uuid, Pool>);

// impl<'a, 'r> FromRequest<'a, 'r> for DbSessions {
//     type Error = ();

//     fn from_request(request: &'a Request<'r>) -> request::Outcome<DbSessions, ()> {
//         let locked_session = request.guard::<State<LockedSession>>()?;

//         match locked_session.inner().read() {
//             Ok(session) => {
//                 let sessions = (&*session).clone();
//                 Outcome::Success(sessions)
//             }
//             Err(_) => Outcome::Failure((Status::ServiceUnavailable, ())),
//         }
//     }
// }

// #[derive(Serialize, Deserialize, Debug)]
// pub struct SessionId(Uuid);

// impl SessionId {
//     fn is_valid(key: &str) -> Result<Uuid, uuid::ParseError> {
//         Uuid::parse_str(key)
//     }
// }

// impl<'a, 'r> FromRequest<'a, 'r> for SessionId {
//     type Error = ();

//     fn from_request(request: &'a Request<'r>) -> request::Outcome<SessionId, ()> {
//         let keys: Vec<_> = request.headers().get("x-session-id").collect();
//         if keys.len() != 1 {
//             return Outcome::Failure((Status::BadRequest, ()));
//         }

//         match SessionId::is_valid(keys[0]) {
//             Ok(key) => Outcome::Success(SessionId(key)),
//             Err(_) => Outcome::Forward(()),
//         }
//     }
// }

// impl Deref for SessionId {
//     type Target = Uuid;

//     fn deref(&self) -> &Self::Target {
//         &self.0
//     }
// }

// // An alias to the type for a pool of Diesel Postgresql connections.
// pub type Pool = r2d2::Pool<PostgresConnectionManager>;
