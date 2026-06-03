use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

/// Represents a geographic entity (Country, State, City, or Locality).
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow, ToSchema)]
pub struct GeoEntity {
    pub id: i64,
    pub name: String,
    pub entity_type: String,
    pub parent_id: Option<i64>,
    pub country_iso: String,
    pub latitude: f64,
    pub longitude: f64,
}

/// Represents a tokenized real estate property.
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow, ToSchema)]
pub struct Property {
    pub id: i64,
    pub display_name: String,
    pub geo_entity_id: i64,
    pub listing_type: String,
    pub property_type: String,
    pub status: String,
    pub total_property_value: Option<f64>,
    pub token_size: Option<f64>,
}

/// Inbound JSON payload for creating a property via the admin API.
#[derive(Debug, Clone, Deserialize, ToSchema)]
pub struct CreatePropertyRequest {
    pub property: PropertyInput,
    pub geo_entities: Vec<GeoEntityInput>,
}

/// Property data from the admin API request body.
#[derive(Debug, Clone, Deserialize, ToSchema)]
pub struct PropertyInput {
    pub id: i64,
    pub display_name: String,
    pub geo_entity_id: i64,
    pub listing_type: String,
    pub property_type: String,
    pub status: String,
    pub total_property_value: Option<f64>,
    pub token_size: Option<f64>,
}

/// Geo entity data from the admin API request body.
#[derive(Debug, Clone, Deserialize, ToSchema)]
pub struct GeoEntityInput {
    pub id: i64,
    pub name: String,
    pub entity_type: String,
    pub parent_id: Option<i64>,
    pub country_iso: String,
    pub latitude: f64,
    pub longitude: f64,
}

/// Filters applied at the SQLite layer (post-Meilisearch).
#[derive(Debug, Default, Clone, Deserialize, ToSchema)]
pub struct PropertyFilters {
    pub property_type: Option<String>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub min_token: Option<f64>,
    pub max_token: Option<f64>,
}
