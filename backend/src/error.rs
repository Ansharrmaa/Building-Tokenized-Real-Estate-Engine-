use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;

/// Unified application error type.
/// All production code paths propagate errors via `?` — zero `unwrap()` calls.
#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("Search index error: {0}")]
    Search(String),

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Internal error: {0}")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::Database(e) => {
                tracing::error!("Database error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal database error".to_string())
            }
            AppError::Search(msg) => {
                tracing::error!("Search error: {}", msg);
                (StatusCode::INTERNAL_SERVER_ERROR, format!("Search error: {}", msg))
            }
            AppError::Unauthorized(msg) => {
                (StatusCode::UNAUTHORIZED, msg.clone())
            }
            AppError::BadRequest(msg) => {
                (StatusCode::BAD_REQUEST, msg.clone())
            }
            AppError::NotFound(msg) => {
                (StatusCode::NOT_FOUND, msg.clone())
            }
            AppError::Internal(e) => {
                tracing::error!("Internal error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error".to_string())
            }
        };

        let body = json!({
            "error": message,
        });

        (status, Json(body)).into_response()
    }
}

/// Convenience type alias for route handlers.
pub type AppResult<T> = Result<T, AppError>;
