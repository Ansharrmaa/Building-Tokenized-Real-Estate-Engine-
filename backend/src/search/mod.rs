use meilisearch_sdk::client::Client;
use sqlx::SqlitePool;

use crate::db::queries;
use crate::error::AppError;

pub mod documents;
pub mod index;

use documents::{GeoPoint, SearchDocument};

/// Create a Meilisearch client.
pub fn create_client(url: &str, api_key: &str) -> Client {
    Client::new(url, Some(api_key)).expect("Failed to create Meilisearch client") // OK: startup-only, not a request handler
}

/// Upsert a single property document into the Meilisearch index.
/// This flattens the property + geo entity hierarchy into the search document format.
pub async fn upsert_property_document(
    client: &Client,
    pool: &SqlitePool,
    property_id: i64,
) -> Result<(), AppError> {
    let property = queries::get_property(pool, property_id).await?;
    let geo_entity = queries::get_geo_entity(pool, property.geo_entity_id).await?;
    let location_text = queries::build_location_text(pool, property.geo_entity_id).await?;

    let doc = SearchDocument {
        id: format!("prop_{}", property.id),
        target_id: property.id,
        display_name: property.display_name,
        location_text,
        country_iso: geo_entity.country_iso,
        entity_type: "Property".to_string(),
        listing_type: Some(property.listing_type),
        status: Some(property.status.to_lowercase()),
        geo: Some(GeoPoint {
            lat: geo_entity.latitude,
            lng: geo_entity.longitude,
        }),
    };

    let idx = client.index(index::INDEX_NAME);
    idx.add_or_update(&[doc], Some("id"))
        .await
        .map_err(|e| AppError::Search(format!("Failed to upsert property doc: {}", e)))?;

    Ok(())
}

/// Upsert a single geo entity document into the Meilisearch index.
/// Only indexes Cities and Localities (not States/Countries) to keep search lean.
pub async fn upsert_geo_entity_document(
    client: &Client,
    pool: &SqlitePool,
    geo_id: i64,
) -> Result<(), AppError> {
    let geo_entity = queries::get_geo_entity(pool, geo_id).await?;

    // Only index Cities and Localities for search suggestions
    if geo_entity.entity_type != "City" && geo_entity.entity_type != "Locality" {
        return Ok(());
    }

    let location_text = queries::build_location_text(pool, geo_id).await?;
    let prefix = match geo_entity.entity_type.as_str() {
        "City" => "city",
        "Locality" => "loc",
        _ => "geo",
    };

    let doc = SearchDocument {
        id: format!("{}_{}", prefix, geo_entity.id),
        target_id: geo_entity.id,
        display_name: geo_entity.name,
        location_text,
        country_iso: geo_entity.country_iso,
        entity_type: geo_entity.entity_type,
        listing_type: None, // Explicitly null for geo entities
        status: None,
        geo: Some(GeoPoint {
            lat: geo_entity.latitude,
            lng: geo_entity.longitude,
        }),
    };

    let idx = client.index(index::INDEX_NAME);
    idx.add_or_update(&[doc], Some("id"))
        .await
        .map_err(|e| AppError::Search(format!("Failed to upsert geo doc: {}", e)))?;

    Ok(())
}

/// Seed the entire Meilisearch index from SQLite data.
/// Called during bootstrap to populate the search index.
pub async fn seed_index(client: &Client, pool: &SqlitePool) -> Result<(), AppError> {
    let mut documents: Vec<SearchDocument> = Vec::new();

    // Index all geo entities (Cities and Localities only)
    let geo_entities = queries::get_all_geo_entities(pool).await?;
    for geo in &geo_entities {
        if geo.entity_type != "City" && geo.entity_type != "Locality" {
            continue;
        }

        let location_text = queries::build_location_text(pool, geo.id).await?;
        let prefix = match geo.entity_type.as_str() {
            "City" => "city",
            "Locality" => "loc",
            _ => "geo",
        };

        documents.push(SearchDocument {
            id: format!("{}_{}", prefix, geo.id),
            target_id: geo.id,
            display_name: geo.name.clone(),
            location_text,
            country_iso: geo.country_iso.clone(),
            entity_type: geo.entity_type.clone(),
            listing_type: None,
            status: None,
            geo: Some(GeoPoint {
                lat: geo.latitude,
                lng: geo.longitude,
            }),
        });
    }

    // Index all properties
    let properties = queries::get_all_properties(pool).await?;
    for prop in &properties {
        let geo_entity = geo_entities
            .iter()
            .find(|g| g.id == prop.geo_entity_id)
            .ok_or_else(|| {
                AppError::NotFound(format!(
                    "Geo entity {} not found for property {}",
                    prop.geo_entity_id, prop.id
                ))
            })?;

        let location_text = queries::build_location_text(pool, prop.geo_entity_id).await?;

        documents.push(SearchDocument {
            id: format!("prop_{}", prop.id),
            target_id: prop.id,
            display_name: prop.display_name.clone(),
            location_text,
            country_iso: geo_entity.country_iso.clone(),
            entity_type: "Property".to_string(),
            listing_type: Some(prop.listing_type.clone()),
            status: Some(prop.status.to_lowercase()),
            geo: Some(GeoPoint {
                lat: geo_entity.latitude,
                lng: geo_entity.longitude,
            }),
        });
    }

    // Bulk upsert all documents
    let idx = client.index(index::INDEX_NAME);
    if !documents.is_empty() {
        idx.add_or_update(&documents, Some("id"))
            .await
            .map_err(|e| AppError::Search(format!("Failed to seed index: {}", e)))?;
    }

    tracing::info!("Meilisearch index seeded with {} documents", documents.len());
    Ok(())
}
