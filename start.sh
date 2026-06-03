#!/bin/bash
set -e

# Ensure data directory exists
mkdir -p /data

# Start Meilisearch in the background
echo "Starting Meilisearch..."
meilisearch --master-key "$MEILISEARCH_API_KEY" --db-path /data/meili_data --no-analytics &
MEILI_PID=$!

# Wait for Meilisearch to boot up
sleep 2

# Check if SQLite DB exists, if not, create and seed it
if [ ! -f /data/real_estate.db ]; then
  echo "Initializing SQLite database..."
  sqlite3 /data/real_estate.db < /app/scripts/migrate.sql
  sqlite3 /data/real_estate.db < /app/scripts/seed.sql
fi

# Start the Rust backend in the foreground
echo "Starting Tokenized Real Estate Backend..."
tokenized-real-estate-backend
