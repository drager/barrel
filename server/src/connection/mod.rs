pub mod db;
pub mod pg_connection;

// use connection::pg_connection::PgDatabaseError;
use r2d2;
use r2d2_postgres::PostgresConnectionManager;
use std::collections::HashMap;
use std::ops::Deref;
use std::sync::{Arc, Mutex, RwLock};
use uuid::{self, Uuid};
use std::fmt::{self, Display};

pub trait DatabaseConnection {
    type Connection;
    type Error;
    type ConnectConfig;
    // An alias to the type for a pool of database connections.
    type Pool;

    // struct ConnectConfig {...} trait DatabaseConnection { fn connect(cfg: ConnectConfig)
    // fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError>;
    fn connect(
        connection_data: ConnectionData,
        db_sessions: &ArcSessions,
    ) -> Result<SessionId, Self::Error>;
    fn init_db_pool(config: Self::ConnectConfig) -> Result<Self::Pool, Self::Error>;
    fn get_databases(db_conn: Self::Connection) -> Result<Vec<Database>, Self::Error>;
    fn get_tables(db_conn: Self::Connection) -> Result<Vec<Table>, Self::Error>;
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ConnectionData {
    host: String,
    port: u16,
    username: String,
    password: String,
    database: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Database {
    pub name: String,
    pub oid: u32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Table {
    pub name: String,
    pub schema: String,
    pub owner: String,
}

#[allow(dead_code)]
enum DatabaseType {
    PostgreSQL,
    Sqlite,
    MySQL,
}

pub type Pool = r2d2::Pool<PostgresConnectionManager>;

impl DbSessions {
    pub fn add(&mut self, session_id: Uuid, db_conn: Pool) -> Option<Pool> {
        self.0.insert(session_id, db_conn)
    }

    pub fn get<'a>(&'a self, session_id: &'a Uuid) -> Option<&'a Pool> {
        self.0.get(session_id)
    }
}

pub fn init_sessions() -> ArcSessions {
    Arc::new(Mutex::new(DbSessions(HashMap::new())))
}

#[derive(Debug, Clone)]
pub struct DbSessions(HashMap<Uuid, Pool>);

pub type ArcSessions = Arc<Mutex<DbSessions>>;
pub type LockedSession = RwLock<DbSessions>;

#[derive(Serialize, Deserialize, Debug, Copy, Clone)]
pub struct SessionId(pub Uuid);

impl SessionId {
    pub fn is_valid(key: &str) -> Result<SessionId, uuid::ParseError> {
        Uuid::parse_str(key).map(SessionId)
    }

    pub fn new() -> Self {
        SessionId(Uuid::new_v4())
    }
}

impl Display for SessionId {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl Deref for SessionId {
    type Target = Uuid;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}
