pub mod pg_connection;

pub trait DatabaseConnection {
    type Connection;
    type ConnectionError;
    type ConnectConfig;
    // An alias to the type for a pool of database connections.
    type Pool;

    // struct ConnectConfig {...} trait DatabaseConnection { fn connect(cfg: ConnectConfig)
    // fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError>;
    fn init_db_pool(config: Self::ConnectConfig) -> Result<Self::Pool, Self::ConnectionError>;
    fn get_databases(db_conn: Self::Connection) -> Result<Vec<Database>, Self::ConnectionError>;
    fn get_tables(db_conn: Self::Connection) -> Result<Vec<Table>, Self::ConnectionError>;
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
