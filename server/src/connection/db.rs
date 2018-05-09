use actix::{Actor, Handler, Message, SyncContext};
use connection::pg_connection::{PgDatabaseConnection, PgError};
use connection::Pool;
use connection::{ConnectionData, DatabaseConnection, DbSessions, LockedSession, SessionId};

pub struct DbExecutor(pub LockedSession);
pub struct GetSession(pub SessionId);

impl Actor for DbExecutor {
    type Context = SyncContext<Self>;
}

impl Actor for GetSession {
    type Context = SyncContext<Self>;
}

impl Message for ConnectionData {
    type Result = Result<SessionId, PgError>;
}

impl Message for SessionId {
    type Result = Result<Pool, PgError>;
}

impl Handler<ConnectionData> for DbExecutor {
    type Result = Result<SessionId, PgError>;

    fn handle(&mut self, msg: ConnectionData, _: &mut Self::Context) -> Self::Result {
        let db_session = &self.0;
        PgDatabaseConnection::connect(msg, db_session)
    }
}

impl Handler<SessionId> for GetSession {
    type Result = Result<Pool, PgError>;

    fn handle(&mut self, msg: SessionId, _ctx: &mut Self::Context) -> Self::Result {
        let db_session = self.0.get(&msg);
        // let c = DbSessions::get(*self.0, &msg);
        db_session
            .ok_or(PgError::NoDbSession)
            .map(|session| session.to_owned())
    }
}
