use axum::{
    extract::{ConnectInfo, Request},
    http::header::AUTHORIZATION,
    middleware::Next,
    response::Response,
};
use std::net::SocketAddr;

use crate::error::AppError;

/// Middleware that validates Bearer token authentication and IP whitelist.
///
/// Extracts the `Authorization: Bearer <token>` header and compares
/// it against the configured `ADMIN_API_KEY`.
/// Also validates the client's IP against `ADMIN_IP_WHITELIST`.
pub async fn auth_middleware(
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    request: Request,
    next: Next,
) -> Result<Response, AppError> {
    // 1. IP Isolation Strategy
    let allowed_ips_str = std::env::var("ADMIN_IP_WHITELIST")
        .unwrap_or_else(|_| "127.0.0.1,::1".to_string());
    
    let allowed_ips: Vec<&str> = allowed_ips_str.split(',').map(|s| s.trim()).collect();
    let client_ip = addr.ip().to_string();

    if !allowed_ips.contains(&client_ip.as_str()) {
        tracing::warn!("Blocked unauthorized IP access attempt from {}", client_ip);
        return Err(AppError::Unauthorized(format!("IP address {} not whitelisted", client_ip)));
    }

    // 2. Bearer Token Validation
    let admin_key = std::env::var("ADMIN_API_KEY")
        .unwrap_or_else(|_| "super-secret-admin-token-2024".to_string());

    let auth_header = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .ok_or_else(|| AppError::Unauthorized("Missing Authorization header".to_string()))?;

    // Expect format: "Bearer <token>"
    let token = auth_header
        .strip_prefix("Bearer ")
        .ok_or_else(|| AppError::Unauthorized("Invalid Authorization format. Expected: Bearer <token>".to_string()))?;

    if token != admin_key {
        return Err(AppError::Unauthorized("Invalid API key".to_string()));
    }

    Ok(next.run(request).await)
}
