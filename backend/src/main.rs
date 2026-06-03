use meilisearch_sdk::client::Client;
use sqlx::SqlitePool;
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};

mod config;
mod db;
mod error;
mod middleware;
mod routes;
mod search;

/// Shared application state passed to all route handlers.
pub struct AppState {
    pub db_pool: SqlitePool,
    pub meili_client: Client,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing/logging
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    // Load .env file (ignore errors if file doesn't exist)
    let _ = dotenvy::dotenv();

    // Load configuration
    let cfg = config::AppConfig::from_env()?;
    tracing::info!("Configuration loaded — binding to {}:{}", cfg.host, cfg.port);

    // Create the data directory if it doesn't exist
    if let Some(_parent) = std::path::Path::new("../data").parent() {
        let _ = std::fs::create_dir_all("../data");
    }
    let _ = std::fs::create_dir_all("../data");

    // Initialize SQLite pool with WAL mode
    let db_pool = db::create_pool(&cfg.database_url).await?;

    // Run migrations (creates tables if they don't exist)
    db::run_migrations(&db_pool).await?;

    // Seed database with initial data
    db::run_seed(&db_pool).await?;

    // Initialize Meilisearch client
    let meili_client = search::create_client(&cfg.meilisearch_url, &cfg.meilisearch_api_key);
    tracing::info!("Meilisearch client initialized at {}", cfg.meilisearch_url);

    // Configure Meilisearch index (searchable, filterable, ranking rules)
    search::index::configure_index(&meili_client).await?;

    // Seed the Meilisearch index from SQLite data
    search::seed_index(&meili_client, &db_pool).await?;

    // Build shared application state
    let state = Arc::new(AppState {
        db_pool,
        meili_client,
    });

    // CORS configuration — permissive for development
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // Build the router
    let app = routes::create_router(state).layer(cors);

    // Serve static files (Flutter Web Build)
    let frontend_dir = "../frontend/build/web";
    let serve_dir = tower_http::services::ServeDir::new(frontend_dir)
        .not_found_service(tower_http::services::ServeFile::new(format!("{}/index.html", frontend_dir)));

    let app = app.fallback_service(serve_dir);

    // Bind and serve
    let addr: SocketAddr = format!("{}:{}", cfg.host, cfg.port)
        .parse()
        .map_err(|e| anyhow::anyhow!("Invalid bind address: {}", e))?;

    tracing::info!("Server starting on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await?;

    Ok(())
}
