-- seed.sql — Initial data for Tokenized Real Estate Search & Ingestion Engine
-- Depends on migrate.sql having been run first.

-- ============================================================
-- Geo Entities: Countries
-- ============================================================
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (1, 'India', 'Country', NULL, 'IN', 20.5937, 78.9629);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (2, 'United Arab Emirates', 'Country', NULL, 'AE', 23.4241, 53.8478);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (3, 'Singapore', 'Country', NULL, 'SG', 1.3521, 103.8198);

-- ============================================================
-- Geo Entities: States
-- ============================================================
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (10, 'Maharashtra', 'State', 1, 'IN', 19.7515, 75.7139);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (11, 'Madhya Pradesh', 'State', 1, 'IN', 22.9734, 78.6569);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (12, 'Delhi NCR', 'State', 1, 'IN', 28.7041, 77.1025);

-- ============================================================
-- Geo Entities: Cities
-- ============================================================
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (20, 'Mumbai', 'City', 10, 'IN', 19.0760, 72.8777);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (21, 'Pune', 'City', 10, 'IN', 18.5204, 73.8567);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (22, 'Indore', 'City', 11, 'IN', 22.7196, 75.8577);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (23, 'Delhi', 'City', 12, 'IN', 28.6139, 77.2090);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (24, 'Dubai', 'City', 2, 'AE', 25.2048, 55.2708);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (25, 'Singapore City', 'City', 3, 'SG', 1.3521, 103.8198);

-- ============================================================
-- Geo Entities: Localities
-- ============================================================
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (50, 'Bandra', 'Locality', 20, 'IN', 19.0596, 72.8295);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (51, 'Dadar', 'Locality', 20, 'IN', 19.0176, 72.8472);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (52, 'Connaught Place', 'Locality', 23, 'IN', 28.6315, 77.2167);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (53, 'Palasia', 'Locality', 22, 'IN', 22.7232, 75.8804);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (54, 'Dubai Marina', 'Locality', 24, 'AE', 25.0805, 55.1403);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (55, 'Marina Bay', 'Locality', 25, 'SG', 1.2814, 103.8585);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (56, 'Koregaon Park', 'Locality', 21, 'IN', 18.5362, 73.8936);

-- ============================================================
-- Properties
-- ============================================================
INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9211, 'Godrej Horizon', 51, 'Marketplace', 'Residential', 'Active', 25000000, 50000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9212, 'Lodha Altamount', 50, 'NewLaunch', 'Residential', 'Active', 150000000, 300000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9213, 'Marina Heights Tower', 54, 'Marketplace', 'Office', 'Active', 80000000, 160000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9214, 'Marina Bay Residences', 55, 'NewLaunch', 'Residential', 'Active', 120000000, 240000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9215, 'Phoenix Marina Mall', 50, 'Marketplace', 'Shop', 'Active', 45000000, 90000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9216, 'Indore Trade Center', 53, 'NewLaunch', 'OtherCommercial', 'Active', 18000000, 36000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9217, 'CP Business Hub', 52, 'Marketplace', 'Office', 'SoldOut', 35000000, 70000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9218, 'Pune Farmhouse Estates', 56, 'NewLaunch', 'Farmhouse', 'Active', 55000000, 110000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9219, 'Mumbai Warehouse Park', 51, 'Marketplace', 'Warehouse', 'Active', 22000000, 44000);

-- ============================================================
-- MORE GEO ENTITIES & PROPERTIES ADDED FOR SCALING TEST
-- ============================================================

-- New Countries
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (4, 'United States', 'Country', NULL, 'US', 37.0902, -95.7129);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (5, 'United Kingdom', 'Country', NULL, 'GB', 55.3781, -3.4360);

-- New States
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (13, 'New York', 'State', 4, 'US', 40.7128, -74.0060);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (14, 'England', 'State', 5, 'GB', 51.5072, -0.1276);

-- New Cities
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (26, 'New York City', 'City', 13, 'US', 40.7128, -74.0060);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (27, 'London', 'City', 14, 'GB', 51.5072, -0.1276);

-- New Localities
INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (60, 'Manhattan', 'Locality', 26, 'US', 40.7831, -73.9712);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (61, 'Brooklyn', 'Locality', 26, 'US', 40.6782, -73.9442);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (62, 'Mayfair', 'Locality', 27, 'GB', 51.5100, -0.1456);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (63, 'Canary Wharf', 'Locality', 27, 'GB', 51.5048, -0.0186);

INSERT OR IGNORE INTO geo_entities (id, name, entity_type, parent_id, country_iso, latitude, longitude)
VALUES (64, 'Palm Jumeirah', 'Locality', 24, 'AE', 25.1124, 55.1390);

-- New Properties
INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9220, 'Empire State Suites', 60, 'NewLaunch', 'Office', 'Active', 250000000, 500000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9221, 'Brooklyn Tech Warehouse', 61, 'Marketplace', 'Warehouse', 'SoldOut', 45000000, 90000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9222, 'Mayfair High-Street Shop', 62, 'Marketplace', 'Shop', 'Active', 85000000, 170000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9223, 'Canary Wharf Trading Floor', 63, 'NewLaunch', 'Office', 'Active', 310000000, 620000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9224, 'The Palm Jumeirah Villas', 64, 'NewLaunch', 'Residential', 'Active', 55000000, 110000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9225, 'Sentosa Cove Residences', 25, 'Marketplace', 'Residential', 'Active', 65000000, 130000);

INSERT OR IGNORE INTO properties (id, display_name, geo_entity_id, listing_type, property_type, status, total_property_value, token_size)
VALUES (9226, 'Central Park Towers', 60, 'Marketplace', 'Residential', 'SoldOut', 120000000, 240000);
