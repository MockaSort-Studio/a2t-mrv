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

### Schema revision for column compression

TimescaleDB's columnar compression relies on segment grouping and delta/dictionary encoding. It works best on typed columns with repeated or monotone values; JSONB is opaque binary from the compressor's perspective and gets only block-level ZSTD (~2–3× at best). `provenance` and `values` are the two largest columns per row — and both are currently JSONB.

**The core problem:** the current schema embeds `source_type` inside `provenance` JSONB. This prevents using it as a `compress_segmentby` segment key — the compressor cannot see inside JSONB. Without a good segment key, rows in a chunk are ordered by insert sequence, not by logical grouping, which degrades delta and dictionary encoding on every other column.

**Proposed revision — extract `source_type` as a typed column:**

Move `source_type` out of `provenance` JSONB into a dedicated `TEXT NOT NULL` column (or a Postgres enum if the set is stable). This is the single highest-leverage schema change for compression:

- Enables `compress_segmentby = 'source_type, activity_id'` — rows are grouped by project-source pair before columnar encoding
- `source_type` itself compresses to near-zero as a dictionary column (3 values: `MANUAL_ENTRY`, `REMOTE_SENSING`, `MODEL_OUTPUT`)
- Within a (source_type, activity_id) segment, `measured_at` values are nearly monotone → delta encoding drops storage to ~1–2 bytes per timestamp
- `is_superseded` is almost always `false` → constant-column compression
- `activity_id` cardinality is bounded per chunk → dictionary benefit

Original rationale for keeping `source_type` in JSONB was avoiding null column sprawl from non-homogeneous schemas. That rationale applies to `values` (methodology payload varies by source type and version) — not to `source_type`, which is a bounded discriminator shared across all rows. Extracting it does not reopen the null-sprawl problem.

**Recommended compression policy:**

```sql
ALTER TABLE raw_measurements SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'source_type, activity_id',
  timescaledb.compress_orderby   = 'measured_at DESC'
);
```

Expected compression on typed columns (`source_type`, `activity_id`, `measured_at`, `is_superseded`, `superseded_by`, `created_at`): **10–20×**.
Expected compression on JSONB columns (`provenance`, `values`): **2–3×** (ZSTD block only).
Mixed-row estimate for the full table: **4–8×** overall, vs the ~3–5× originally projected without a proper segment key.

**`values` JSONB:** accepting JSONB here is correct given non-homogeneous methodology payloads. If the team later converges on fixed schemas per `source_type` (e.g., always `{co2_kg, uncertainty_pct}` for `MODEL_OUTPUT`), typed columns per source category would push compression to 10–20× on that column too. That is a product decision to be made as schemas stabilize — flag for future revisit, not a blocker now.

**`provenance` JSONB after `source_type` extraction:** residual content is source-specific metadata (API keys masked, version strings, endpoint identifiers). Cardinality is unpredictable; ZSTD is the right tool. No further extraction recommended without profiling actual payloads.

### Alternatives compared

The table below evaluates the realistic alternatives for this context: Elixir/Phoenix/Ecto stack, single-tenant, IoT-scale append-only writes, indefinite retention with cold-tier migration, and CRCF-28 strict dedup at DB level.

| Engine | Postgres/Ecto compatible | Strict `UNIQUE` constraint | Time-partitioned UNIQUE (CRCF-28) | Cold tiering | Columnar compression | Write throughput (TSBS¹) |
|---|---|---|---|---|---|---|
| **TimescaleDB** | Yes — native Postgres extension | Yes | Yes — via Path A hash design | Native chunk tiering | 3–10× mixed; up to 94% on typed workloads² | ~300K rows/s³ |
| **Plain Postgres** | Yes — native | Yes | No — RANGE partitioning has the same UNIQUE limitation | Manual partition detach/archive | None (heap only) | ~50–100K rows/s with JSONB index overhead |
| **ClickHouse** | No — HTTP/binary protocol; no production Ecto adapter | Eventual only — `ReplacingMergeTree` deduplicates asynchronously at merge time | Not applicable | TTL-based to S3/HDFS — mature | 10–50× columnar⁴ | 1M–5M rows/s⁴ |
| **QuestDB** | Partial — PG wire protocol subset; no production Ecto adapter | No — `UNIQUE` constraints are not supported on partitioned tables | Blocked | No native tiering | 10–20× columnar⁵ | ~1.4M rows/s⁵ |
| **InfluxDB v3 (IOx)** | No — Arrow Flight SQL; no Ecto adapter | No — not a relational concept in InfluxDB | Blocked | Native (Parquet/object storage) | 10–100× (Parquet-based) | Very high (line protocol) |

**Why each alternative is blocked:**

- **Plain Postgres:** same `UNIQUE`-constraint-on-partitioned-table problem as TimescaleDB, but with zero compression and no native tiering. Picks up all the constraint complexity with none of the storage benefits. At 100M+ rows, query performance degrades without columnar encoding; heap bloat from append-only inserts becomes operational burden.
- **ClickHouse:** compression and ingest throughput are best-in-class, but `ReplacingMergeTree` deduplication is asynchronous and eventually consistent — duplicates exist in query results until a background merge runs. CRCF-28 requires deterministic rejection of duplicates at insert time. This is a hard architectural incompatibility, not a configuration issue.
- **QuestDB:** no `UNIQUE` constraint support on partitioned tables at all. CRCF-28 cannot be satisfied at the DB layer. Dedup would fall entirely to the application layer — the requirement is explicit that DB-level enforcement is mandatory. No path forward.
- **InfluxDB v3:** not a relational database. No `UNIQUE` constraints. No Ecto adapter. The line-protocol ingestion model is a different paradigm from the Elixir/Phoenix stack. Brings operational complexity (separate TSDB alongside the relational store) with no compatibility path.

**Conclusion:** TimescaleDB is the only option that satisfies all three binding constraints simultaneously — Ecto-native, strict `UNIQUE` at DB level, and native cold-tier lifecycle management. ClickHouse would be the engineering choice if CRCF-28 were relaxed to application-layer dedup; that is a product decision, not an architectural one.

---
¹ TSBS = Time Series Benchmark Suite, open benchmark: github.com/timescale/tsbs. Results are hardware-dependent; figures are representative order-of-magnitude, not guarantees.
² TimescaleDB compression benchmark: timescale.com/blog/time-series-compression-algorithms-explained — 94% reduction on TSBS multi-host dataset (typed columns only).
³ TimescaleDB ingest rate from TSBS multi-worker results; degrades with JSONB index overhead.
⁴ ClickHouse ClickBench public benchmark: clickhouse.com/benchmark. Columnar workload, no UNIQUE constraints tested.
⁵ QuestDB TSBS results published at questdb.io/blog/2021/05/10/questdb-loki-influxdb-apache-kafka-comparison.
