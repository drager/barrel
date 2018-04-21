use postgres::{self, Connection as PgConnection, TlsMode};
use postgres::params::ConnectParams;
use connection::DatabaseConnection;
use r2d2_postgres::{PostgresConnectionManager, TlsMode as R2D2TlsMode};
use r2d2::{self, PooledConnection};
use connection::{Database, Table};


#[derive(Serialize)]
pub struct PgDatabaseConnection {}

impl DatabaseConnection for PgDatabaseConnection {
    type Connection = PooledConnection<PostgresConnectionManager>;
    type ConnectionError = PgError;
    type ConnectConfig = ConnectParams;
    // An alias to the type for a pool of Postgresql connections.
    type Pool = r2d2::Pool<PostgresConnectionManager>;

    /// Connects to a database
    ///
    /// # Example
    ///
    /// PgDatabaseConnection::connect("postgres://postgres@localhost:5433");
    // fn connect(config: Self::ConnectConfig) -> Result<Self::Connection, Self::ConnectionError> {
    //     PgConnection::connect(config, TlsMode::None).map_err(PgError::from)
    // }
    /// Initializes a database pool.
    fn init_db_pool(
        database_url: Self::ConnectConfig,
    ) -> Result<Self::Pool, Self::ConnectionError> {
        let config = r2d2::Config::default();
        // Do TlsMode::None for now...
        let manager = PostgresConnectionManager::new(database_url, R2D2TlsMode::None).unwrap();
        r2d2::Pool::new(config, manager).map_err(PgError::from)
    }

    fn get_databases(db_conn: Self::Connection) -> Result<Vec<Database>, Self::ConnectionError> {
        db_conn
            .query(
                "SELECT datname, oid FROM pg_database WHERE NOT datistemplate ORDER BY datname ASC",
                &[],
            )
            .map(|rows| {
                rows.iter()
                    .map(|row| {
                        Database {
                            name: row.get("datname"),
                            oid: row.get("oid"),
                        }
                    })
                    .collect()
            })
            .map_err(PgError::from)
    }

    fn get_tables(db_conn: Self::Connection) -> Result<Vec<Table>, Self::ConnectionError> {
        db_conn
            .query(
                "SELECT
                    n.nspname as \"schema\",
                    c.relname as \"name\",
                CASE c.relkind
                    WHEN 'r' THEN 'table'
                    WHEN 'v' THEN 'view'
                    WHEN 'm' THEN 'materialized view'
                    WHEN 'i' THEN 'index'
                    WHEN 'S' THEN 'sequence'
                    WHEN 's' THEN 'special'
                    WHEN 'f' THEN 'foreign table'
                END as \"type\",
                    pg_catalog.pg_get_userbyid(c.relowner) as \"owner\"
                FROM pg_catalog.pg_class c
                    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relkind IN ('r','')
                    AND n.nspname <> 'pg_catalog'
                    AND n.nspname <> 'information_schema'
                    AND n.nspname !~ '^pg_toast'
                    AND pg_catalog.pg_table_is_visible(c.oid)
                ORDER BY 1,2;
                ",
                &[],
            )
            .map(|rows| {
                rows.iter()
                    .map(|row| {
                        Table {
                            name: row.get("name"),
                            schema: row.get("schema"),
                            owner: row.get("owner"),
                        }
                    })
                    .collect()
            })
            .map_err(PgError::from)
    }
}

#[derive(Debug)]
pub enum PgError {
    PostgresError(postgres::Error),
    PoolError(r2d2::InitializationError),
}

impl From<postgres::Error> for PgError {
    fn from(err: postgres::Error) -> PgError {
        PgError::PostgresError(err)
    }
}

impl From<r2d2::InitializationError> for PgError {
    fn from(err: r2d2::InitializationError) -> PgError {
        PgError::PoolError(err)
    }
}
