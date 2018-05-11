use actix::{Actor, Handler, Message, SyncContext};
use connection::pg_connection::{PgDatabaseConnection, PgError};
use connection::{ArcSessions, Pool};
use connection::{ConnectionData, DatabaseConnection, DbSessions, SessionId};

#[derive(Debug)]
pub struct DbExecutor(pub ArcSessions);

#[derive(Debug)]
pub struct GetSession(pub SessionId);

impl Actor for DbExecutor {
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
        let db_sessions = &self.0;
        PgDatabaseConnection::connect(msg, db_sessions)
    }
}

impl Handler<GetSession> for DbExecutor {
    type Result = Result<Pool, PgError>;

    fn handle(&mut self, msg: GetSession, _ctx: &mut Self::Context) -> Self::Result {
        let db_sessions = self.0.lock();
        let result = db_sessions
            .map_err(|_err| PgError::CouldNotWriteDbSession)
            .and_then(|sessions| {
                DbSessions::get(&sessions, &msg.0)
                    .ok_or(PgError::NoDbSession)
                    .map(|s| s.to_owned())
            });
        result
    }
}
