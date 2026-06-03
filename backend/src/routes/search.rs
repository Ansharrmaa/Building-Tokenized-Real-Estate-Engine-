use axum::{extract::Query, extract::State, Json};
use meilisearch_sdk::search::SearchQuery;
use serde::Deserialize;
use utoipa::IntoParams;
use std::collections::HashSet;
use std::sync::Arc;

use crate::db::queries;
use crate::error::{AppError, AppResult};
use crate::search::documents::{SearchDocument, SearchResult};
use crate::search::index::INDEX_NAME;
use crate::AppState;

/// Query parameters for the search endpoint.
#[derive(Debug, Deserialize, IntoParams)]
pub struct SearchParams {
    /// The search query string
    pub q: Option<String>,
    /// 2-character ISO country code for result boosting
    pub country: Option<String>,
    /// Filter by listing type (NewLaunch or Marketplace)
    pub listing_type: Option<String>,
    /// Filter by status (Active or SoldOut)
    pub status: Option<String>,
}

/// Query parameters for the properties filter endpoint.
#[derive(Debug, Deserialize, IntoParams)]
pub struct PropertyFilterParams {
    /// Comma-separated list of property IDs
    pub ids: Option<String>,
    /// Filter by property type
    pub property_type: Option<String>,
    /// Minimum total property value
    pub min_value: Option<f64>,
    /// Maximum total property value
    pub max_value: Option<f64>,
    /// Minimum token size
    pub min_token: Option<f64>,
    /// Maximum token size
    pub max_token: Option<f64>,
}

/// GET /api/v1/search?q={query}&country={iso}
///
/// Powered by Meilisearch for fuzzy/typo-tolerant search.
/// Implements country-based result boosting via dual-query strategy:
/// 1. First query: filtered to user's country_iso → these rank first
/// 2. Second query: all results without country filter → fill remaining slots
/// Results are deduplicated and interleaved.
///
/// STRICT zero-leaks rule: returns [] when no real matches exist.
#[utoipa::path(
    get,
    path = "/api/v1/search",
    params(SearchParams),
    responses(
        (status = 200, description = "Search executed successfully", body = [SearchResult]),
    )
)]
pub async fn search(
    State(state): State<Arc<AppState>>,
    Query(params): Query<SearchParams>,
) -> AppResult<Json<Vec<SearchResult>>> {
    let query_str = match &params.q {
        Some(q) if !q.trim().is_empty() => q.trim().to_string(),
        _ => {
            if params.country.is_some() {
                "".to_string()
            } else {
                return Ok(Json(Vec::new())); // Empty query -> empty results
            }
        }
    };

    let index = state.meili_client.index(INDEX_NAME);

    // Build Meilisearch filter expressions
    let mut filter_parts: Vec<String> = Vec::new();
    if let Some(ref lt) = params.listing_type {
        filter_parts.push(format!("listing_type = \"{}\"", lt));
    }
    if let Some(ref st) = params.status {
        filter_parts.push(format!("status = \"{}\"", st.to_lowercase()));
    }

    let base_filter = if filter_parts.is_empty() {
        None
    } else {
        Some(filter_parts.join(" AND "))
    };

    let mut final_results: Vec<SearchDocument> = Vec::new();
    let mut seen_ids: HashSet<String> = HashSet::new();

    // COUNTRY BOOSTING: Dual-query strategy
    // Query 1: Results matching the user's country (ranked first)
    if let Some(ref country) = params.country {
        let country_filter = match &base_filter {
            Some(bf) => format!("country_iso = \"{}\" AND {}", country, bf),
            None => format!("country_iso = \"{}\"", country),
        };

        let mut country_query = SearchQuery::new(&index);
        country_query.with_query(&query_str);
        country_query.with_limit(20);
        country_query.with_filter(&country_filter);

        let country_results = index
            .execute_query::<SearchDocument>(&country_query)
            .await
            .map_err(|e| AppError::Search(format!("Meilisearch country query failed: {}", e)))?;

        for hit in country_results.hits {
            if seen_ids.insert(hit.result.id.clone()) {
                final_results.push(hit.result);
            }
        }
    }

    // Query 2: All results (no country filter) — fills remaining slots
    let mut global_query = SearchQuery::new(&index);
    global_query.with_query(&query_str);
    global_query.with_limit(20);

    if let Some(ref bf) = base_filter {
        global_query.with_filter(bf);
    }

    let global_results = index
        .execute_query::<SearchDocument>(&global_query)
        .await
        .map_err(|e| AppError::Search(format!("Meilisearch global query failed: {}", e)))?;

    for hit in global_results.hits {
        if seen_ids.insert(hit.result.id.clone()) {
            final_results.push(hit.result);
        }
    }

    // ZERO-LEAKS RULE: If no results, return empty array
    if final_results.is_empty() {
        return Ok(Json(Vec::new()));
    }

    // Convert to polymorphic response format
    let pool = &state.db_pool;
    let mut response: Vec<SearchResult> = Vec::new();

    for doc in &final_results {
        let secondary_text = match doc.entity_type.as_str() {
            "Property" => {
                // For properties, find the geo entity and build secondary text
                let target_id = doc.target_id;
                match queries::get_property(pool, target_id).await {
                    Ok(prop) => {
                        queries::build_secondary_text(pool, prop.geo_entity_id)
                            .await
                            .unwrap_or_else(|_| doc.location_text.clone())
                    }
                    Err(_) => doc.location_text.clone(),
                }
            }
            "Locality" | "City" => {
                // For geo entities, build secondary from parent chain
                queries::build_secondary_text(pool, doc.target_id)
                    .await
                    .unwrap_or_else(|_| doc.location_text.clone())
            }
            _ => doc.location_text.clone(),
        };

        response.push(SearchResult {
            id: doc.id.clone(),
            target_id: doc.target_id,
            display_name: doc.display_name.clone(),
            secondary_text,
            entity_type: doc.entity_type.clone(),
            // listing_type is explicitly null for Locality/City results
            listing_type: match doc.entity_type.as_str() {
                "Property" => doc.listing_type.clone(),
                _ => None,
            },
        });
    }

    Ok(Json(response))
}

/// GET /api/v1/properties?ids=1,2,3&property_type=Office&min_value=100000&...
///
/// SQLite-layer filtering endpoint.
/// Takes property IDs (from Meilisearch search results) and applies
/// granular filters: property_type, total_property_value range, token_size range.
#[utoipa::path(
    get,
    path = "/api/v1/properties",
    params(PropertyFilterParams),
    responses(
        (status = 200, description = "Properties filtered successfully", body = [crate::db::models::Property]),
    )
)]
pub async fn filter_properties(
    State(state): State<Arc<AppState>>,
    Query(params): Query<PropertyFilterParams>,
) -> AppResult<Json<Vec<crate::db::models::Property>>> {
    let ids: Vec<i64> = match &params.ids {
        Some(ids_str) => {
            ids_str
                .split(',')
                .filter_map(|s| s.trim().parse::<i64>().ok())
                .collect()
        }
        None => return Ok(Json(Vec::new())),
    };

    if ids.is_empty() {
        return Ok(Json(Vec::new()));
    }

    let results = queries::get_properties_filtered(
        &state.db_pool,
        &ids,
        params.property_type.as_deref(),
        params.min_value,
        params.max_value,
        params.min_token,
        params.max_token,
    )
    .await?;

    Ok(Json(results))
}
