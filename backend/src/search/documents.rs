use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

/// Flattened document structure for Meilisearch indexing.
/// Matches the exact schema from the assignment spec.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct SearchDocument {
    /// Prefixed ID: "prop_9211" for properties, "loc_50" for localities, "city_20" for cities
    pub id: String,

    /// The raw Int64 ID for matching back to SQLite
    pub target_id: i64,

    /// Display name (e.g., "Godrej Horizon", "Mumbai", "Bandra")
    pub display_name: String,

    /// Flattened location path (e.g., "Dadar, Mumbai, Maharashtra, India")
    pub location_text: String,

    /// 2-character ISO country code
    pub country_iso: String,

    /// "Property", "Locality", "City", "State", "Country"
    pub entity_type: String,

    /// "NewLaunch" or "Marketplace" for properties; None for geo entities
    pub listing_type: Option<String>,

    /// "Active" or "SoldOut" for properties; None for geo entities
    pub status: Option<String>,

    /// Geographic coordinates for spatial sorting
    #[serde(rename = "_geo", skip_serializing_if = "Option::is_none")]
    pub geo: Option<GeoPoint>,
}

/// Geographic coordinate point for Meilisearch _geo field.
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct GeoPoint {
    pub lat: f64,
    pub lng: f64,
}

/// Polymorphic search result returned by the API.
/// listing_type is explicitly null for Locality/City results.
#[derive(Debug, Serialize, ToSchema)]
pub struct SearchResult {
    pub id: String,
    pub target_id: i64,
    pub display_name: String,
    pub secondary_text: String,
    pub entity_type: String,
    pub listing_type: Option<String>,
}
