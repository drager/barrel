use postgres::{Connection as PgConnection, TlsMode, Error as PgError};
use postgres::params::ConnectParams;
use connection::DatabaseConnection;


#[derive(Serialize)]
pub struct PgDatabaseConnection {}

impl DatabaseConnection for PgDatabaseConnection {
    type Connection = PgConnection;
    type ConnectionError = PgError;
    type ConnectConfig = ConnectParams;

    /// Connects to a database
    ///
    /// # Example
    ///
    /// PgDatabaseConnection::connect("postgres://postgres@localhost:5433");
    fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError>
    {
        PgConnection::connect(config, TlsMode::None)
    }
}