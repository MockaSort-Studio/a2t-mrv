# Data Model — Measurement

> Schema decisions for `raw_measurements`, `derived_measurements`, and `derived_measurement_sources`.
> See design item #15.

## Database engine

**Verdict: No to TimescaleDB for `raw_measurements` and `derived_measurements`. Plain Postgres.**

The decisive blocker is CRCF-28. TimescaleDB hypertables require any `UNIQUE` constraint to include the partitioning (time) column — meaning `UNIQUE(content_hash)` either fails at hypertable creation or must be rewritten as `UNIQUE(content_hash, measured_at)`. The rewritten form does not prevent duplicate `content_hash` values across different timestamps, which breaks dedup semantics entirely. There is no clean workaround that preserves both the TimescaleDB partitioning model and a globally-enforced content hash.

**TimescaleDB features evaluated:**

| Feature | Applicable? | Reason |
|---|---|---|
| Hypertable time partitioning | No | Blocked by `UNIQUE(content_hash)` — CRCF-28 |
| Columnar compression | Minimal | Payload is JSONB; compression targets typed scalar columns |
| Continuous aggregates | No | `derived_measurements` is application-computed, not window-aggregated |
| Chunk exclusion on time scans | Would help | Moot — hypertable is blocked |

**Operational concerns:**

- Global `UNIQUE` constraints across chunks are unsupported; this is fundamental to TimescaleDB's architecture, not a version limitation.
- JSONB columns (`provenance`, `values`) make up the bulk of row data; columnar compression gains are negligible.
- Single-tenant workload: plain Postgres with indexes on `(activity_id, measured_at)` handles expected volume without partitioning overhead.
- TimescaleDB adds an extension dependency with its own version lifecycle, separate from Postgres; constrains managed hosting options.
- `derived_measurements` has no time partitioning column and no time-series query pattern — hypertable conversion offers nothing.

**Plain Postgres path:**

- `UNIQUE(content_hash)` — globally enforced, satisfies CRCF-28.
- Index on `(activity_id, measured_at)` — covers range scans.
- Supersession FK chain and append-only enforcement work natively in Ecto migrations without extension-specific DDL.
