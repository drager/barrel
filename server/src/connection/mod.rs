pub mod pg_connection;

pub trait DatabaseConnection {
    type Connection;
    type ConnectionError;

    fn connect(connection_string: String) -> Result<Self::Connection, Self::ConnectionError>;
}

enum DatabaseType {
    PostgreSQL,
    Sqlite,
    MySQL,
}
