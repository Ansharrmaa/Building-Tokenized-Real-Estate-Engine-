#!/bin/bash
set -e

echo "=== Tokenized Real Estate Engine Starting ==="

# Ensure data directory exists
mkdir -p /data

# Start Meilisearch in the background
echo "Starting Meilisearch..."
meilisearch --master-key "$MEILISEARCH_API_KEY" --db-path /data/meili_data --no-analytics &
MEILI_PID=$!

# Wait for Meilisearch to be ready (up to 30 seconds)
echo "Waiting for Meilisearch to be ready..."
for i in $(seq 1 30); do
  if curl -s http://127.0.0.1:7700/health > /dev/null 2>&1; then
    echo "Meilisearch is ready!"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "WARNING: Meilisearch did not respond in 30s, continuing anyway..."
  fi
  sleep 1
done

# Check if SQLite DB exists, if not, create and seed it
if [ ! -f /data/real_estate.db ]; then
  echo "Initializing SQLite database..."
  sqlite3 /data/real_estate.db < /app/scripts/migrate.sql
  sqlite3 /data/real_estate.db < /app/scripts/seed.sql
  echo "Database seeded."
fi

# Start the Rust backend in the foreground
echo "Starting Tokenized Real Estate Backend..."
exec tokenized-real-estate-backend
