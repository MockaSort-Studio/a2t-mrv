# Data Model — Measurement

> Schema decisions for `raw_measurements`, `derived_measurements`, and `derived_measurement_sources`.
> See design item #15.

## Database engine

**Verdict: Yes to TimescaleDB — conditional on `content_hash` including `measured_at` in its hash input.**

The original rejection assumed a fixed, small-to-moderate scale. IoT data with varying time rates (hourly and below) and indefinite retention changes the calculus: any engine that handles this volume correctly requires time-based partitioning. Once partitioning is required, TimescaleDB is strictly better than plain Postgres for this workload — and the CRCF-28 constraint is resolvable without compromise.

**Why partitioning is now required:**

- Hourly IoT readings across multiple projects accumulate to hundreds of millions of rows within years; plain Postgres without partitioning degrades on both writes and range scans at that scale.
- Indefinite retention with cold-tier migration demands chunk-level lifecycle management — native Postgres has no first-class tiering primitive; TimescaleDB does.
- Native Postgres declarative partitioning (PARTITION BY RANGE) faces the *same* `UNIQUE` constraint limitation as TimescaleDB. The CRCF-28 problem is not specific to TimescaleDB; it applies to any partition strategy.

**Resolving CRCF-28 under partitioning:**

TimescaleDB requires `UNIQUE` constraints to include the partitioning column (`measured_at`). `UNIQUE(content_hash)` alone is unsupported. Two paths exist:

- **Path A (recommended):** define `content_hash` as SHA-256 over `(source_type, activity_id, measured_at, values_payload)`. Then `UNIQUE(content_hash, measured_at)` is semantically equivalent to `UNIQUE(content_hash)` — collisions across different timestamps are impossible because `measured_at` is part of the hashed input. CRCF-28 is fully satisfied.
- **Path B (flag, not recommended):** exclude `measured_at` from the hash to catch same-payload resubmissions across time. This makes `UNIQUE(content_hash, measured_at)` weaker and conflicts with any partitioning strategy. If this is the intended semantics, the requirements need revisiting before a DB engine is chosen — that is a product decision, not an architectural one.

Path A is assumed going forward. If the team intends Path B semantics, escalate to Old Major before implementation.

**TimescaleDB features evaluated:**

| Feature | Applicable? | Reason |
|---|---|---|
| Hypertable time partitioning | Yes | Resolved via `content_hash` including `measured_at` (Path A) |
| Chunk-level compression | Yes | Compresses older chunks; JSONB gains are partial but scalar columns in provenance benefit |
| Tiered storage (cold-tier) | Yes | Native chunk tiering to object storage — directly addresses indefinite retention requirement |
| Continuous aggregates | No | `derived_measurements` is application-computed, not window-aggregated |
| Chunk exclusion on time scans | Yes | Range queries on `(activity_id, measured_at)` benefit directly |

**Operational concerns:**

- Ecto compatibility: TimescaleDB is a Postgres extension; Ecto migrations work natively. Hypertable creation requires a raw `execute/1` migration step (`SELECT create_hypertable(...)`); no Ecto-level abstraction needed.
- Extension lifecycle: TimescaleDB versioning is independent of Postgres; managed hosting options (Timescale Cloud, AWS RDS with TimescaleDB) are mature. Self-hosted requires coordinating extension upgrades with Postgres major upgrades.
- `derived_measurements` has no time partitioning column and no IoT-scale write pattern — leave as a plain Postgres table; only `raw_measurements` is a hypertable.
- Compression on JSONB: `values` and `provenance` columns are not directly columnar-compressible, but `activity_id`, `source_type`, `measured_at`, and `content_hash` are — typical compression ratios on mixed rows are 3–5×.

**TimescaleDB implementation path:**

- `raw_measurements` → hypertable on `measured_at`; chunk interval to be tuned to ingest rate (start at 1 month).
- `UNIQUE(content_hash, measured_at)` — satisfies CRCF-28 under Path A.
- Compression policy on chunks older than configurable threshold (e.g., 90 days).
- Tiering policy for cold chunks (configurable; align with retention/compliance requirements).
- Index on `(activity_id, measured_at)` — retained; chunk exclusion amplifies its effect.
- Supersession FK chain and append-only enforcement (`CRCF-25`) remain unchanged — hypertable does not affect insert-only semantics.
