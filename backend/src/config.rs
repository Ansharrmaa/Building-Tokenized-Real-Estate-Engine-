use std::env;

/// Application configuration loaded from environment variables.
#[derive(Debug, Clone)]
pub struct AppConfig {
    pub database_url: String,
    pub meilisearch_url: String,
    pub meilisearch_api_key: String,
    pub admin_api_key: String,
    pub host: String,
    pub port: u16,
}

impl AppConfig {
    /// Load configuration from environment variables.
    /// Returns an error if any required variable is missing.
    pub fn from_env() -> anyhow::Result<Self> {
        Ok(Self {
            database_url: env::var("DATABASE_URL")
                .unwrap_or_else(|_| "sqlite:../data/real_estate.db?mode=rwc".to_string()),
            meilisearch_url: env::var("MEILISEARCH_URL")
                .unwrap_or_else(|_| "http://localhost:7700".to_string()),
            meilisearch_api_key: env::var("MEILISEARCH_API_KEY")
                .unwrap_or_else(|_| "masterKey".to_string()),
            admin_api_key: env::var("ADMIN_API_KEY")
                .unwrap_or_else(|_| "super-secret-admin-token-2024".to_string()),
            host: env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
            port: env::var("PORT")
                .unwrap_or_else(|_| "3000".to_string())
                .parse::<u16>()
                .map_err(|e| anyhow::anyhow!("Invalid PORT value: {}", e))?,
        })
    }
}
