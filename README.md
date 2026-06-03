# Tokenized Real Estate Search & Ingestion Engine

A high-performance backend for searching and managing tokenized real estate properties across multiple geographies, built with Rust (Actix-web), SQLite, and Meilisearch.

## Tech Stack

| Component         | Technology                        |
|-------------------|-----------------------------------|
| **Language**      | Rust (2021 edition)               |
| **Web Framework** | Actix-web 4                       |
| **Database**      | SQLite via sqlx (async, WAL mode) |
| **Search Engine** | Meilisearch                       |
| **Serialization** | serde / serde_json                |
| **Async Runtime** | Tokio                             |

## Features

- **Fuzzy full-text search** across properties and geo entities with typo tolerance
- **Country boosting** — results from the user's country appear first
- **Two-tier filtering** — Meilisearch handles text search; SQLite handles numeric range filters
- **Hierarchical geo entities** — Country → State → City → Locality
- **Tokenized properties** — Each property has a total value and token size for fractional ownership
- **Admin API** — CRUD operations for properties and geo entities with API key authentication
- **Sub-15ms search latency** end-to-end

## Project Structure

```
├── backend/            # Rust application (Actix-web)
│   ├── src/
│   ├── Cargo.toml
│   └── .env            # Environment configuration
├── scripts/
│   ├── migrate.sql     # Database schema
│   └── seed.sql        # Initial seed data
├── data/               # SQLite database (created at runtime)
├── bootstrap.sh        # Linux/Mac setup script
├── bootstrap.ps1       # Windows setup script
├── ARCH.md             # Architecture documentation
└── README.md           # This file
```

## Prerequisites

- [Rust](https://rustup.rs/) (1.75+ recommended)
- [SQLite3](https://www.sqlite.org/download.html) CLI (for bootstrap scripts)
- Internet connection (to download Meilisearch on first run)

## Quick Start

### Linux / macOS

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File bootstrap.ps1
```

### Manual Setup

1. **Start Meilisearch** on port 7700 with master key `masterKey`:
   ```bash
   ./meilisearch --master-key masterKey --http-addr 127.0.0.1:7700
   ```

2. **Create and seed the database:**
   ```bash
   mkdir -p data
   sqlite3 data/real_estate.db < scripts/migrate.sql
   sqlite3 data/real_estate.db < scripts/seed.sql
   ```

3. **Build and run the backend:**
   ```bash
   cd backend
   cargo run --release
   ```

The server starts on `http://0.0.0.0:3000`.

## API Endpoints

### Search

| Method | Endpoint              | Description                          |
|--------|-----------------------|--------------------------------------|
| GET    | `/api/search`         | Search properties and geo entities   |
| GET    | `/api/properties`     | List/filter properties               |
| GET    | `/api/geo-entities`   | List/filter geo entities             |

### Admin (requires `X-API-Key` header)

| Method | Endpoint                   | Description              |
|--------|----------------------------|--------------------------|
| POST   | `/admin/properties`        | Create a property        |
| PUT    | `/admin/properties/:id`    | Update a property        |
| DELETE | `/admin/properties/:id`    | Delete a property        |
| POST   | `/admin/geo-entities`      | Create a geo entity      |
| PUT    | `/admin/geo-entities/:id`  | Update a geo entity      |
| DELETE | `/admin/geo-entities/:id`  | Delete a geo entity      |

## Configuration

All configuration is via environment variables (see `backend/.env`):

| Variable             | Default                                     | Description                     |
|----------------------|---------------------------------------------|---------------------------------|
| `DATABASE_URL`       | `sqlite:../data/real_estate.db?mode=rwc`    | SQLite connection string        |
| `MEILISEARCH_URL`    | `http://localhost:7700`                     | Meilisearch URL                 |
| `MEILISEARCH_API_KEY`| `masterKey`                                 | Meilisearch master/admin key    |
| `ADMIN_API_KEY`      | `super-secret-admin-token-2024`             | API key for admin endpoints     |
| `HOST`               | `0.0.0.0`                                  | Server bind address             |
| `PORT`               | `3000`                                      | Server port                     |

## Architecture

See [ARCH.md](ARCH.md) for detailed architecture documentation covering:
- SQLite connection pooling and WAL mode
- Meilisearch ranking rules and country boosting strategy
- Two-tier search architecture
- Performance benchmark targets
- Background task strategy for search index updates

## License

This project is part of a backend engineering assignment.
