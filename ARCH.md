# Architecture — Tokenized Real Estate Search & Ingestion Engine

## 1. SQLite Connection Pooling

The application maintains a pool of **5 connections** via `sqlx::SqlitePool`. Every connection is configured through an `after_connect` hook that executes:

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
```

### Why WAL Mode Is Critical

SQLite's default rollback journal mode acquires an **exclusive lock** on the database file for every write, blocking all concurrent readers. Under Tokio's async runtime — where dozens of tasks may issue queries simultaneously — this serialization creates a bottleneck that stalls the entire event loop.

**WAL (Write-Ahead Logging)** decouples reads from writes:

- **Readers never block writers.** Read transactions see a consistent snapshot of the database at the moment they start, regardless of concurrent writes. This is essential when search queries and property ingestion run on the same Tokio runtime.
- **Writers never block readers.** A write appends to the WAL file instead of modifying the main database, so in-flight reads are unaffected.
- **Only writer-vs-writer conflicts remain.** Since our pool has 5 connections and writes are infrequent (property upserts), write contention is negligible.

`synchronous = NORMAL` reduces the number of `fsync()` calls by only syncing at WAL checkpoints rather than on every commit. Combined with WAL, this yields ~2-3× faster writes with minimal durability risk (data is safe against application crashes; only an OS-level crash during a checkpoint could cause loss of the most recent transaction).

`foreign_keys = ON` ensures referential integrity between `properties.geo_entity_id` and `geo_entities.id` at the database level.

---

## 2. Meilisearch Ranking & Country Boosting

### Default Ranking Rules

Meilisearch indexes for both `geo_entities` and `properties` use the default ranking rule chain:

1. **words** — Documents matching more query words rank higher.
2. **typo** — Documents with fewer typos rank higher.
3. **proximity** — Documents where matched words are closer together rank higher.
4. **attribute** — Matches in earlier-declared searchable attributes rank higher (e.g., `display_name` before `property_type`).
5. **sort** — Respects explicit sort parameters in the query.
6. **exactness** — Exact word matches rank higher than prefix matches.

### Country Boosting Strategy

Users searching from India should see Indian properties first, but still see Dubai and Singapore results afterward. Rather than dynamically modifying ranking rules per request (which would require index-level setting changes and trigger re-indexing), we implement a **dual-query strategy**:

1. **Query 1 — Country-filtered:** Search with `filter: "country_iso = IN"` (using the user's detected country ISO code). This returns the top N matches from the user's home country.
2. **Query 2 — Unfiltered:** The same search query without a country filter. This returns global results.
3. **Interleave:** Results are merged client-side — country-matched results appear first, followed by non-country results (deduplicated by ID).

This approach has several advantages:
- **No index mutation per request.** Ranking rules stay static.
- **Predictable latency.** Both queries run in parallel via `tokio::join!`, and Meilisearch responds in <5ms per query.
- **Deterministic ordering.** Country results always precede international results, with consistent sub-ordering within each tier.

---

## 3. Search Architecture — Two-Tier Filtering

The search pipeline splits filtering responsibilities between Meilisearch and SQLite based on what each system does best:

```
Client Request
    │
    ▼
┌───────────────────────────────────┐
│  Tier 1: Meilisearch              │
│  ─ Fuzzy text search (typo-tolerant)│
│  ─ Filter: listing_type, status   │
│  ─ Returns: matching document IDs │
└──────────────┬────────────────────┘
               │ IDs
               ▼
┌───────────────────────────────────┐
│  Tier 2: SQLite                   │
│  ─ Filter: property_type          │
│  ─ Filter: value range            │
│  ─ Filter: token_size range       │
│  ─ JOIN with geo_entities          │
│  ─ Returns: full property records │
└───────────────────────────────────┘
               │
               ▼
         JSON Response
```

### Why This Split?

- **Meilisearch** excels at fuzzy text matching and faceted filtering on low-cardinality string fields (`listing_type` has 2 values, `status` has 2 values). These filters are applied during the search itself, reducing the candidate set before IDs are returned.
- **SQLite** excels at numeric range queries (`total_property_value BETWEEN ? AND ?`, `token_size >= ?`) and relational joins. These operations are O(log n) with proper indexes and don't benefit from Meilisearch's inverted index.
- **Combining both** avoids bloating the Meilisearch index with numeric fields that would need to be filterable (increasing index size and update latency) while keeping the SQLite query fast by pre-narrowing the ID set.

---

## 4. Benchmark Targets

| Component              | Target Latency | Notes                                           |
|------------------------|----------------|-------------------------------------------------|
| **End-to-end search**  | < 15 ms        | From HTTP request receipt to response write      |
| **Meilisearch query**  | < 5 ms         | Single query; dual queries run in parallel       |
| **SQLite filtered query** | < 3 ms      | Using `WHERE id IN (...)` with indexed PKs       |
| **Serialization**      | < 2 ms         | `serde_json` serialization of response payload   |
| **Network/framework**  | < 5 ms         | Actix-web request parsing + response framing     |

### How We Hit These Numbers

- **Meilisearch** runs in-process on the same machine, eliminating network round-trips. Its LMDB-backed storage engine serves simple queries in 1-3ms.
- **SQLite `WHERE id IN (...)`** with a primary key lookup is effectively O(k × log n) where k is the number of IDs (typically 10-20) and n is total rows. With <10K properties, this completes in <1ms.
- **serde_json** serializes flat structs (no nested recursion) at ~500MB/s. A typical 20-result response is ~4KB, serialized in <0.1ms.

---

## 5. Background Task Strategy

Property and geo entity mutations follow a **write-through** pattern:

```
HTTP Request (POST /admin/properties)
    │
    ▼
┌──────────────────────┐
│ 1. Validate payload  │
│ 2. SQLite INSERT/     │
│    UPDATE (authoritative)│
│ 3. Return HTTP 201   │◄── Response sent here
└──────────┬───────────┘
           │ tokio::spawn
           ▼
┌──────────────────────┐
│ 4. Upsert document   │
│    into Meilisearch   │
│    (async, non-blocking)│
└──────────────────────┘
```

### Key Design Decisions

- **SQLite is the source of truth.** The HTTP response is sent as soon as the SQLite transaction commits. If Meilisearch ingestion fails, the data is safe in SQLite and a retry mechanism can re-sync.
- **`tokio::spawn` for fire-and-forget.** The Meilisearch upsert runs on a separate Tokio task. This guarantees the HTTP response latency is never affected by Meilisearch's indexing time (which can spike to 50-200ms for batch upserts).
- **No blocking the event loop.** Since `tokio::spawn` schedules the task on the Tokio thread pool, the HTTP handler's future completes immediately after spawning. The Actix-web worker thread is freed to handle the next request.
- **Error logging, not error propagation.** If the Meilisearch upsert fails (network error, index not found), the error is logged with `tracing::error!` but not propagated to the client. A periodic background reconciliation job can detect and fix drift between SQLite and Meilisearch.

### Consistency Model

This is an **eventually consistent** design. For a brief window (typically <100ms), a newly inserted property may be present in SQLite but not yet searchable via Meilisearch. This is acceptable because:

1. Property listings are not time-critical to the millisecond.
2. Admin users see a success response immediately.
3. Search results converge within one Meilisearch indexing cycle (~50-200ms).
