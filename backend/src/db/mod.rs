use sqlx::sqlite::SqlitePoolOptions;
use sqlx::{Executor, SqlitePool};

pub mod models;
pub mod queries;

/// Creates a SQLite connection pool with WAL mode and production-ready pragmas.
///
/// Every connection in the pool will have:
/// - `journal_mode=WAL` — enables concurrent readers with a single writer
/// - `synchronous=NORMAL` — safe durability with better write throughput
/// - `foreign_keys=ON` — enforces referential integrity
pub async fn create_pool(database_url: &str) -> anyhow::Result<SqlitePool> {
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .after_connect(|conn, _meta| {
            Box::pin(async move {
                conn.execute("PRAGMA journal_mode=WAL;").await?;
                conn.execute("PRAGMA synchronous=NORMAL;").await?;
                conn.execute("PRAGMA foreign_keys=ON;").await?;
                Ok(())
            })
        })
        .connect(database_url)
        .await?;

    tracing::info!("SQLite pool created with WAL mode (max_connections=5)");
    Ok(pool)
}

/// Runs the migration SQL to create tables if they don't exist.
pub async fn run_migrations(pool: &SqlitePool) -> anyhow::Result<()> {
    let migration_sql = include_str!("../../../scripts/migrate.sql");

    // Split by semicolons and execute each statement
    for statement in migration_sql.split(';') {
        let trimmed = statement.trim();
        if !trimmed.is_empty() {
            sqlx::query(trimmed).execute(pool).await?;
        }
    }

    tracing::info!("Database migrations completed");
    Ok(())
}

/// Runs the seed SQL to insert initial data.
pub async fn run_seed(pool: &SqlitePool) -> anyhow::Result<()> {
    let seed_sql = include_str!("../../../scripts/seed.sql");

    for statement in seed_sql.split(';') {
        let trimmed = statement.trim();
        if !trimmed.is_empty() {
            sqlx::query(trimmed).execute(pool).await?;
        }
    }

    tracing::info!("Database seeded with initial data");
    Ok(())
}
