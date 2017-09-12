use postgres::params::IntoConnectParams;

pub mod pg_connection;

pub trait DatabaseConnection {
    type Connection;
    type ConnectionError;
    type ConnectConfig;

    // struct ConnectConfig {...} trait DatabaseConnection { fn connect(cfg: ConnectConfig)
    fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError>;
}

enum DatabaseType {
    PostgreSQL,
    Sqlite,
    MySQL,
}
