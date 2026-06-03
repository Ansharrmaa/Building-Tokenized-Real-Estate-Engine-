-- migrate.sql — Schema for Tokenized Real Estate Search & Ingestion Engine
-- Run this before seed.sql to create all required tables.

CREATE TABLE IF NOT EXISTS geo_entities (
  id BIGINT PRIMARY KEY,
  name TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  parent_id BIGINT,
  country_iso TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS properties (
  id BIGINT PRIMARY KEY,
  display_name TEXT NOT NULL,
  geo_entity_id BIGINT NOT NULL,
  listing_type TEXT NOT NULL,
  property_type TEXT NOT NULL,
  status TEXT NOT NULL,
  total_property_value NUMERIC,
  token_size NUMERIC,
  FOREIGN KEY(geo_entity_id) REFERENCES geo_entities(id)
);
