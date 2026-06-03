use meilisearch_sdk::client::Client;

use crate::error::AppError;

/// Index name constant used throughout the application.
pub const INDEX_NAME: &str = "real_estate";

/// Configure the Meilisearch index with the correct settings:
/// - Searchable attributes (display_name, location_text)
/// - Filterable attributes (country_iso, listing_type, status, entity_type)
/// - Sortable attributes (_geo for spatial queries)
/// - Ranking rules (default order works well for our use case)
pub async fn configure_index(client: &Client) -> Result<(), AppError> {
    let index = client.index(INDEX_NAME);

    // Set searchable attributes — order matters for attribute ranking rule
    index
        .set_searchable_attributes(["display_name", "location_text"])
        .await
        .map_err(|e| AppError::Search(format!("Failed to set searchable attributes: {}", e)))?;

    // Set filterable attributes — enables filter expressions in search queries
    index
        .set_filterable_attributes([
            "country_iso",
            "listing_type",
            "status",
            "entity_type",
            "_geo",
        ])
        .await
        .map_err(|e| AppError::Search(format!("Failed to set filterable attributes: {}", e)))?;

    // Set sortable attributes — enables geo-distance sorting for country boosting
    index
        .set_sortable_attributes(["_geo"])
        .await
        .map_err(|e| AppError::Search(format!("Failed to set sortable attributes: {}", e)))?;

    // Set ranking rules — using Meilisearch defaults which handle typo tolerance well
    // The order: words > typo > proximity > attribute > sort > exactness
    index
        .set_ranking_rules([
            "words",
            "typo",
            "proximity",
            "attribute",
            "sort",
            "exactness",
        ])
        .await
        .map_err(|e| AppError::Search(format!("Failed to set ranking rules: {}", e)))?;

    // Configure typo tolerance
    let typo_settings = meilisearch_sdk::settings::TypoToleranceSettings {
        enabled: Some(true),
        min_word_size_for_typos: Some(meilisearch_sdk::settings::MinWordSizeForTypos {
            one_typo: Some(3),
            two_typos: Some(6),
        }),
        disable_on_attributes: None,
        disable_on_words: None,
    };

    index
        .set_typo_tolerance(&typo_settings)
        .await
        .map_err(|e| AppError::Search(format!("Failed to set typo tolerance: {}", e)))?;

    tracing::info!("Meilisearch index '{}' configured successfully", INDEX_NAME);
    Ok(())
}
