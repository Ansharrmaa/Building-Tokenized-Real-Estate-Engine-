use sqlx::SqlitePool;

use super::models::{GeoEntity, GeoEntityInput, Property, PropertyInput};
use crate::error::{AppError, AppResult};

/// Insert or replace a geo entity (upsert semantics).
pub async fn upsert_geo_entity(pool: &SqlitePool, geo: &GeoEntityInput) -> AppResult<()> {
    sqlx::query(
        r#"
        INSERT OR REPLACE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(geo.id)
    .bind(&geo.name)
    .bind(&geo.entity_type)
    .bind(geo.parent_id)
    .bind(&geo.country_iso)
    .bind(geo.latitude)
    .bind(geo.longitude)
    .execute(pool)
    .await?;

    Ok(())
}

/// Insert or replace a property.
pub async fn upsert_property(pool: &SqlitePool, prop: &PropertyInput) -> AppResult<()> {
    sqlx::query(
        r#"
        INSERT OR REPLACE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(prop.id)
    .bind(&prop.display_name)
    .bind(prop.geo_entity_id)
    .bind(&prop.listing_type)
    .bind(&prop.property_type)
    .bind(&prop.status)
    .bind(prop.total_property_value)
    .bind(prop.token_size)
    .execute(pool)
    .await?;

    Ok(())
}

/// Fetch a geo entity by ID.
pub async fn get_geo_entity(pool: &SqlitePool, id: i64) -> AppResult<GeoEntity> {
    let entity = sqlx::query_as::<_, GeoEntity>("SELECT * FROM geo_entities WHERE id = ?")
        .bind(id)
        .fetch_optional(pool)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Geo entity {} not found", id)))?;

    Ok(entity)
}

/// Fetch a property by ID with its associated geo entity chain.
pub async fn get_property(pool: &SqlitePool, id: i64) -> AppResult<Property> {
    let property = sqlx::query_as::<_, Property>("SELECT id, display_name, geo_entity_id, listing_type, property_type, status, CAST(total_property_value AS REAL) as total_property_value, CAST(token_size AS REAL) as token_size FROM properties WHERE id = ?")
        .bind(id)
        .fetch_optional(pool)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Property {} not found", id)))?;

    Ok(property)
}

/// Build the full location text by walking up the geo entity hierarchy.
/// e.g., "Dadar, Mumbai, Maharashtra, India"
pub async fn build_location_text(pool: &SqlitePool, geo_entity_id: i64) -> AppResult<String> {
    let mut parts: Vec<String> = Vec::new();
    let mut current_id = Some(geo_entity_id);

    while let Some(id) = current_id {
        let entity = sqlx::query_as::<_, GeoEntity>("SELECT * FROM geo_entities WHERE id = ?")
            .bind(id)
            .fetch_optional(pool)
            .await?;

        match entity {
            Some(e) => {
                parts.push(e.name);
                current_id = e.parent_id;
            }
            None => break,
        }
    }

    Ok(parts.join(", "))
}

/// Build a secondary text string for search results.
/// For a property: "Locality, City, Country" (excluding the property's own geo entity name in some cases)
/// For a locality: "City, Country"
pub async fn build_secondary_text(pool: &SqlitePool, geo_entity_id: i64) -> AppResult<String> {
    let entity = get_geo_entity(pool, geo_entity_id).await?;

    match entity.entity_type.as_str() {
        "Locality" => {
            // Walk up to get city and country name
            let mut parts: Vec<String> = vec![entity.name.clone()];
            let mut current_id = entity.parent_id;
            while let Some(id) = current_id {
                let parent =
                    sqlx::query_as::<_, GeoEntity>("SELECT * FROM geo_entities WHERE id = ?")
                        .bind(id)
                        .fetch_optional(pool)
                        .await?;
                match parent {
                    Some(p) => {
                        if p.entity_type == "City" || p.entity_type == "Country" {
                            parts.push(p.name.clone());
                        }
                        current_id = p.parent_id;
                    }
                    None => break,
                }
            }
            Ok(parts.join(", "))
        }
        "City" => {
            // Walk up to get country
            let mut parts: Vec<String> = vec![entity.name.clone()];
            let mut current_id = entity.parent_id;
            while let Some(id) = current_id {
                let parent =
                    sqlx::query_as::<_, GeoEntity>("SELECT * FROM geo_entities WHERE id = ?")
                        .bind(id)
                        .fetch_optional(pool)
                        .await?;
                match parent {
                    Some(p) => {
                        if p.entity_type == "Country" {
                            parts.push(p.name.clone());
                        }
                        current_id = p.parent_id;
                    }
                    None => break,
                }
            }
            Ok(parts.join(", "))
        }
        "Country" => Ok(entity.name),
        _ => Ok(entity.name),
    }
}

/// Fetch properties by a list of IDs, with optional filters applied at the SQLite layer.
pub async fn get_properties_filtered(
    pool: &SqlitePool,
    ids: &[i64],
    property_type: Option<&str>,
    min_value: Option<f64>,
    max_value: Option<f64>,
    min_token: Option<f64>,
    max_token: Option<f64>,
) -> AppResult<Vec<Property>> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }

    // Build dynamic query with placeholders
    let placeholders: Vec<String> = ids.iter().map(|_| "?".to_string()).collect();
    let placeholder_str = placeholders.join(",");

    let mut query = format!(
        "SELECT id, display_name, geo_entity_id, listing_type, property_type, status, CAST(total_property_value AS REAL) as total_property_value, CAST(token_size AS REAL) as token_size FROM properties WHERE id IN ({})",
        placeholder_str
    );
    let mut bind_values: Vec<String> = Vec::new();

    if let Some(pt) = property_type {
        query.push_str(" AND property_type = ?");
        bind_values.push(pt.to_string());
    }
    if min_value.is_some() {
        query.push_str(" AND total_property_value >= ?");
    }
    if max_value.is_some() {
        query.push_str(" AND total_property_value <= ?");
    }
    if min_token.is_some() {
        query.push_str(" AND token_size >= ?");
    }
    if max_token.is_some() {
        query.push_str(" AND token_size <= ?");
    }

    // We need to use sqlx::query_as with dynamic binding
    let mut q = sqlx::query_as::<_, Property>(&query);

    // Bind the ID values first
    for id in ids {
        q = q.bind(*id);
    }

    // Bind filter values
    if let Some(pt) = property_type {
        q = q.bind(pt.to_string());
    }
    if let Some(v) = min_value {
        q = q.bind(v);
    }
    if let Some(v) = max_value {
        q = q.bind(v);
    }
    if let Some(v) = min_token {
        q = q.bind(v);
    }
    if let Some(v) = max_token {
        q = q.bind(v);
    }

    let results = q.fetch_all(pool).await?;
    Ok(results)
}

/// Fetch all geo entities.
pub async fn get_all_geo_entities(pool: &SqlitePool) -> AppResult<Vec<GeoEntity>> {
    let entities = sqlx::query_as::<_, GeoEntity>("SELECT * FROM geo_entities")
        .fetch_all(pool)
        .await?;
    Ok(entities)
}

/// Fetch all properties.
pub async fn get_all_properties(pool: &SqlitePool) -> AppResult<Vec<Property>> {
    let properties = sqlx::query_as::<_, Property>("SELECT id, display_name, geo_entity_id, listing_type, property_type, status, CAST(total_property_value AS REAL) as total_property_value, CAST(token_size AS REAL) as token_size FROM properties")
        .fetch_all(pool)
        .await?;
    Ok(properties)
}
