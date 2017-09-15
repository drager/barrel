pub mod pg_connection;

pub trait DatabaseConnection {
    type Connection;
    type ConnectionError;
    type ConnectConfig;
    // An alias to the type for a pool of database connections.
    type Pool;

    // struct ConnectConfig {...} trait DatabaseConnection { fn connect(cfg: ConnectConfig)
    fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError>;
    fn init_db_pool(config: Self::ConnectConfig) -> Result<Self::Pool, Self::ConnectionError>;
}

#[allow(dead_code)]
enum DatabaseType {
    PostgreSQL,
    Sqlite,
    MySQL,
}
