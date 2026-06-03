use axum::{middleware, routing::{get, post}, Router};
use std::sync::Arc;
use utoipa::{
    openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme},
    Modify, OpenApi,
};
use utoipa_swagger_ui::SwaggerUi;

use crate::middleware::auth::auth_middleware;
use crate::AppState;

pub mod admin;
pub mod search;

#[derive(OpenApi)]
#[openapi(
    paths(
        admin::create_property,
        search::search,
        search::filter_properties
    ),
    components(
        schemas(
            crate::db::models::GeoEntity,
            crate::db::models::Property,
            crate::db::models::CreatePropertyRequest,
            crate::db::models::PropertyInput,
            crate::db::models::GeoEntityInput,
            crate::search::documents::SearchResult
        )
    ),
    modifiers(&SecurityAddon),
    tags(
        (name = "admin", description = "Admin onboarding endpoints"),
        (name = "search", description = "Public search endpoints")
    )
)]
pub struct ApiDoc;

struct SecurityAddon;

impl Modify for SecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        if let Some(components) = openapi.components.as_mut() {
            components.add_security_scheme(
                "bearer_auth",
                SecurityScheme::Http(
                    HttpBuilder::new()
                        .scheme(HttpAuthScheme::Bearer)
                        .bearer_format("JWT")
                        .build(),
                ),
            )
        }
    }
}

/// Build the complete application router.
///
/// Routes:
/// - POST /api/v1/admin/properties — protected by Bearer token auth
/// - GET  /api/v1/search            — public, Meilisearch-backed search
/// - GET  /api/v1/properties         — public, SQLite-layer property filtering
pub fn create_router(state: Arc<AppState>) -> Router {
    // Admin routes — protected by auth middleware
    let admin_routes = Router::new()
        .route("/properties", post(admin::create_property))
        .layer(middleware::from_fn(auth_middleware));

    // Public search routes
    let search_routes = Router::new()
        .route("/search", get(search::search))
        .route("/properties", get(search::filter_properties));

    // Combine under /api/v1
    Router::new()
        .merge(SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi()))
        .nest("/api/v1/admin", admin_routes)
        .nest("/api/v1", search_routes)
        .with_state(state)
}
