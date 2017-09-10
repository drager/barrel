use postgres::{Connection as PgConnection, TlsMode, Error as PgError};
use connection::DatabaseConnection;

pub struct PgDatabaseConnection {}

impl DatabaseConnection for PgDatabaseConnection {
    type Connection = PgConnection;
    type ConnectionError = PgError;

    /// Connects to a database
    ///
    /// # Example
    ///
    /// PgDatabaseConnection::connect("postgres://postgres@localhost:5433");
    fn connect(connection_string: String) -> Result<Self::Connection, Self::ConnectionError> {
        println!("CONNECTION_STRING: {:?}", connection_string);
        PgConnection::connect(connection_string, TlsMode::None)
    }
}