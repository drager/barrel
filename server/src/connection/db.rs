use actix::{Actor, Addr, Handler, Message, Syn, SyncContext};
use connection::pg_connection::{PgDatabaseConnection, PgError};
use connection::{ArcSessions, Pool};
use connection::{ConnectionData, DatabaseConnection, DbSessions, SessionId};
use futures::Future;
use r2d2;
use r2d2_postgres;

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

pub fn get_db_session(
    session_id: SessionId,
    state: Addr<Syn, DbExecutor>,
) -> impl Future<
    Item = Result<r2d2::PooledConnection<r2d2_postgres::PostgresConnectionManager>, PgError>,
    Error = PgError,
> {
    state
        .send(GetSession(session_id))
        .map_err(|_| PgError::NoDbSession)
        .from_err()
        .and_then(move |res| {
            res.map(|db_session| db_session.get().map_err(|_| PgError::NoDbSession))
        })
}
