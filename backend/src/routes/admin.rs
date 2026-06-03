use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;

use crate::db::models::CreatePropertyRequest;
use crate::error::{AppError, AppResult};
use crate::search;
use crate::AppState;

/// POST /api/v1/admin/properties
///
/// Protected by Bearer token middleware.
/// Writes full relational data to SQLite in a transaction.
/// After commit, spawns a tokio task to async upsert flattened doc into Meilisearch.
/// Never blocks the HTTP response waiting for Meilisearch.
#[utoipa::path(
    post,
    path = "/api/v1/admin/properties",
    request_body = CreatePropertyRequest,
    responses(
        (status = 201, description = "Property created successfully", body = serde_json::Value),
        (status = 400, description = "Bad request - invalid fields"),
        (status = 401, description = "Unauthorized - invalid token or IP"),
    ),
    security(
        ("bearer_auth" = [])
    )
)]
pub async fn create_property(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<CreatePropertyRequest>,
) -> AppResult<(StatusCode, Json<serde_json::Value>)> {
    let pool = &state.db_pool;

    // Validate required fields
    if payload.property.display_name.is_empty() {
        return Err(AppError::BadRequest("display_name is required".to_string()));
    }

    let valid_listing_types = ["NewLaunch", "Marketplace"];
    if !valid_listing_types.contains(&payload.property.listing_type.as_str()) {
        return Err(AppError::BadRequest(format!(
            "listing_type must be one of: {:?}",
            valid_listing_types
        )));
    }

    let valid_property_types = [
        "Office",
        "Warehouse",
        "OtherCommercial",
        "Farmhouse",
        "Residential",
        "Shop",
    ];
    if !valid_property_types.contains(&payload.property.property_type.as_str()) {
        return Err(AppError::BadRequest(format!(
            "property_type must be one of: {:?}",
            valid_property_types
        )));
    }

    let valid_statuses = ["Active", "SoldOut"];
    if !valid_statuses.contains(&payload.property.status.as_str()) {
        return Err(AppError::BadRequest(format!(
            "status must be one of: {:?}",
            valid_statuses
        )));
    }

    // Execute within a SQLite transaction
    let mut tx = pool.begin().await?;

    // Upsert all geo entities first (they may reference parents via parent_id)
    // Sort by entity_type to ensure countries → states → cities → localities
    let mut sorted_geos = payload.geo_entities.clone();
    sorted_geos.sort_by_key(|g| match g.entity_type.as_str() {
        "Country" => 0,
        "State" => 1,
        "City" => 2,
        "Locality" => 3,
        _ => 4,
    });

    for geo in &sorted_geos {
        sqlx::query(
            r#"INSERT OR REPLACE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
               VALUES (?, ?, ?, ?, ?, ?, ?)"#,
        )
        .bind(geo.id)
        .bind(&geo.name)
        .bind(&geo.entity_type)
        .bind(geo.parent_id)
        .bind(&geo.country_iso)
        .bind(geo.latitude)
        .bind(geo.longitude)
        .execute(&mut *tx)
        .await?;
    }

    // Upsert the property
    sqlx::query(
        r#"INSERT OR REPLACE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)"#,
    )
    .bind(payload.property.id)
    .bind(&payload.property.display_name)
    .bind(payload.property.geo_entity_id)
    .bind(&payload.property.listing_type)
    .bind(&payload.property.property_type)
    .bind(&payload.property.status)
    .bind(payload.property.total_property_value)
    .bind(payload.property.token_size)
    .execute(&mut *tx)
    .await?;

    // Commit the transaction
    tx.commit().await?;

    tracing::info!("Property {} saved to SQLite", payload.property.id);

    // Spawn async Meilisearch upsert — NEVER blocks the HTTP response
    let meili_client = state.meili_client.clone();
    let db_pool = pool.clone();
    let property_id = payload.property.id;
    let geo_ids: Vec<i64> = sorted_geos.iter().map(|g| g.id).collect();

    tokio::spawn(async move {
        // Upsert geo entities into Meilisearch
        for geo_id in geo_ids {
            if let Err(e) = search::upsert_geo_entity_document(&meili_client, &db_pool, geo_id).await {
                tracing::error!("Failed to upsert geo entity {} to Meilisearch: {}", geo_id, e);
            }
        }

        // Upsert the property into Meilisearch
        if let Err(e) = search::upsert_property_document(&meili_client, &db_pool, property_id).await {
            tracing::error!("Failed to upsert property {} to Meilisearch: {}", property_id, e);
        }

        tracing::info!("Property {} synced to Meilisearch", property_id);
    });

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({
            "status": "created",
            "property_id": payload.property.id
        })),
    ))
}
