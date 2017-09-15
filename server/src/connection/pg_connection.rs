use postgres::{Connection as PgConnection, TlsMode, Error as PgError};
use postgres::params::ConnectParams;
use connection::DatabaseConnection;
use r2d2_postgres::{PostgresConnectionManager, TlsMode as R2D2TlsMode};
use r2d2;


#[derive(Serialize)]
pub struct PgDatabaseConnection {}

impl DatabaseConnection for PgDatabaseConnection {
    type Connection = PgConnection;
    type ConnectionError = PgError;
    type ConnectConfig = ConnectParams;
    // An alias to the type for a pool of Postgresql connections.
    type Pool = r2d2::Pool<PostgresConnectionManager>;

    /// Connects to a database
    ///
    /// # Example
    ///
    /// PgDatabaseConnection::connect("postgres://postgres@localhost:5433");
    fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError> {
        PgConnection::connect(config, TlsMode::None)
    }

    /// Initializes a database pool.
    fn init_db_pool(database_url: Self::ConnectConfig)
                    -> Result<Self::Pool, Self::ConnectionError> {
        let config = r2d2::Config::default();
        // Do TlsMode::None for now...
        let manager = PostgresConnectionManager::new(database_url, R2D2TlsMode::None).unwrap();
        Ok(r2d2::Pool::new(config, manager).expect("Failed to create database pool."))
    }
}
