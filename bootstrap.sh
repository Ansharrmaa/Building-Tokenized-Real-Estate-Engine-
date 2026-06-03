#!/usr/bin/env bash
# bootstrap.sh — One-command setup for Tokenized Real Estate Search & Ingestion Engine
# Usage: chmod +x bootstrap.sh && ./bootstrap.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
BACKEND_DIR="$SCRIPT_DIR/backend"
DB_PATH="$DATA_DIR/real_estate.db"
MEILI_VERSION="v1.12.3"
MEILI_PORT=7700
MEILI_MASTER_KEY="masterKey"
MEILI_DIR="$SCRIPT_DIR/.meilisearch"
MEILI_BINARY="$MEILI_DIR/meilisearch"
MEILI_DATA="$MEILI_DIR/data.ms"

echo "============================================"
echo "  Tokenized Real Estate Search Engine"
echo "  Bootstrap Script"
echo "============================================"

# --------------------------------------------------
# Step 1: Download Meilisearch if not present
# --------------------------------------------------
if [ ! -f "$MEILI_BINARY" ]; then
    echo ""
    echo "[1/6] Downloading Meilisearch ${MEILI_VERSION}..."
    mkdir -p "$MEILI_DIR"

    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux)
            case "$ARCH" in
                x86_64)  MEILI_PLATFORM="meilisearch-linux-amd64"  ;;
                aarch64) MEILI_PLATFORM="meilisearch-linux-aarch64" ;;
                *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        Darwin)
            case "$ARCH" in
                x86_64)  MEILI_PLATFORM="meilisearch-macos-amd64"  ;;
                arm64)   MEILI_PLATFORM="meilisearch-macos-apple-silicon" ;;
                *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        *)
            echo "Unsupported OS: $OS. Use bootstrap.ps1 for Windows."
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/meilisearch/meilisearch/releases/download/${MEILI_VERSION}/${MEILI_PLATFORM}"
    echo "  URL: $DOWNLOAD_URL"
    curl -L -o "$MEILI_BINARY" "$DOWNLOAD_URL"
    chmod +x "$MEILI_BINARY"
    echo "  ✓ Meilisearch downloaded to $MEILI_BINARY"
else
    echo ""
    echo "[1/6] Meilisearch binary already present. Skipping download."
fi

# --------------------------------------------------
# Step 2: Start Meilisearch
# --------------------------------------------------
echo ""
echo "[2/6] Starting Meilisearch on port ${MEILI_PORT}..."

# Kill any existing Meilisearch process on the port
if lsof -i :${MEILI_PORT} > /dev/null 2>&1; then
    echo "  Port ${MEILI_PORT} is in use. Attempting to stop existing process..."
    kill $(lsof -t -i :${MEILI_PORT}) 2>/dev/null || true
    sleep 1
fi

mkdir -p "$MEILI_DATA"
"$MEILI_BINARY" \
    --http-addr "127.0.0.1:${MEILI_PORT}" \
    --master-key "$MEILI_MASTER_KEY" \
    --db-path "$MEILI_DATA" \
    --env development \
    > "$MEILI_DIR/meilisearch.log" 2>&1 &
MEILI_PID=$!
echo "  PID: $MEILI_PID"

# --------------------------------------------------
# Step 3: Wait for Meilisearch to be ready
# --------------------------------------------------
echo ""
echo "[3/6] Waiting for Meilisearch to be ready..."

MAX_RETRIES=30
RETRY_COUNT=0
until curl -s "http://127.0.0.1:${MEILI_PORT}/health" | grep -q '"status":"available"'; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "  ✗ Meilisearch failed to start after ${MAX_RETRIES} attempts."
        echo "  Check logs: $MEILI_DIR/meilisearch.log"
        exit 1
    fi
    sleep 1
done
echo "  ✓ Meilisearch is ready."

# --------------------------------------------------
# Step 4: Create SQLite database and run migrations
# --------------------------------------------------
echo ""
echo "[4/6] Setting up SQLite database..."

mkdir -p "$DATA_DIR"

if [ -f "$DB_PATH" ]; then
    echo "  Database already exists. Removing for fresh setup..."
    rm -f "$DB_PATH"
fi

sqlite3 "$DB_PATH" < "$SCRIPTS_DIR/migrate.sql"
echo "  ✓ Schema migration complete."

# --------------------------------------------------
# Step 5: Seed the database
# --------------------------------------------------
echo ""
echo "[5/6] Seeding database with initial data..."

sqlite3 "$DB_PATH" "PRAGMA foreign_keys = ON;" 
sqlite3 "$DB_PATH" < "$SCRIPTS_DIR/seed.sql"

# Verify seed data
GEO_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM geo_entities;")
PROP_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM properties;")
echo "  ✓ Seeded ${GEO_COUNT} geo entities and ${PROP_COUNT} properties."

# --------------------------------------------------
# Step 6: Build and start the Rust backend
# --------------------------------------------------
echo ""
echo "[6/6] Building and starting the Rust backend..."

if ! command -v cargo &> /dev/null; then
    echo "  ✗ Rust/Cargo is not installed. Install from https://rustup.rs"
    exit 1
fi

cd "$BACKEND_DIR"
cargo build --release
echo "  ✓ Build complete."

echo ""
echo "============================================"
echo "  Starting server on http://0.0.0.0:3000"
echo "  Meilisearch: http://127.0.0.1:${MEILI_PORT}"
echo "  SQLite DB:   ${DB_PATH}"
echo "============================================"
echo ""

cargo run --release

# Cleanup: stop Meilisearch when the backend exits
kill $MEILI_PID 2>/dev/null || true
