use actix::{Actor, Handler, Message, SyncContext};
use connection::pg_connection::{PgDatabaseConnection, PgError};
use connection::Pool;
use connection::{ConnectionData, DatabaseConnection, DbSessions, LockedSession, SessionId};

#[derive(Debug)]
pub struct DbExecutor(pub LockedSession);
#[derive(Debug)]
pub struct GetSession(pub SessionId);
#[derive(Debug)]
pub struct ActiveSessions(pub DbSessions);

impl Actor for DbExecutor {
    type Context = SyncContext<Self>;
}

// impl Actor for GetSession {
//     type Context = SyncContext<Self>;
// }

impl Actor for ActiveSessions {
    type Context = SyncContext<Self>;
}

impl Message for ConnectionData {
    type Result = Result<SessionId, PgError>;
}

impl Message for GetSession {
    type Result = Result<Pool, PgError>;
}

impl Handler<ConnectionData> for DbExecutor {
    type Result = Result<SessionId, PgError>;

    fn handle(&mut self, msg: ConnectionData, _: &mut Self::Context) -> Self::Result {
        let db_session = &self.0;
        PgDatabaseConnection::connect(msg, db_session)
    }
}

impl Handler<GetSession> for DbExecutor {
    type Result = Result<Pool, PgError>;

    fn handle(&mut self, msg: GetSession, _ctx: &mut Self::Context) -> Self::Result {
        println!("In get session handle {:?}", msg);
        // let locked_session = self.0;GetSession
        let result = self.0
            .read()
            // .map(|session| (&*session).clone())
            .map_err(|_err| PgError::NoDbSession)
            .and_then(|sessions| {
                DbSessions::get(&sessions, &msg.0)
                    .ok_or(PgError::NoDbSession)
                    .map(|s| s.to_owned())
            });
        // .map(|s| s.to_owned());
        // let result = match locked_session.read() {
        //     Ok(session) => Ok((&*session).clone()),
        //     Err(_) => Err(PgError::NoDbSession),
        // };
        // .get(&msg);
        // let c = DbSessions::get(*self.0, &msg);
        // let s = DbSessions::get(result, &msg);
        // db_session
        //     .ok_or(PgError::NoDbSession)
        //     .map(|session| session.to_owned())
        result
    }
}

// impl Handler<SessionId> for ActiveSessions {
//     type Result = Result<Pool, PgError>;

//     fn handle(&mut self, msg: SessionId, _ctx: &mut Self::Context) -> Self::Result {
//         let db_session = self.0.get(&msg);
//         // let c = DbSessions::get(*self.0, &msg);
//         db_session
//             .ok_or(PgError::NoDbSession)
//             .map(|session| session.to_owned())
//     }
// }
