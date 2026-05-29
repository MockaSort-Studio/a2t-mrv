# Project & Activity — Data Model Design

## Database engine

**Verdict: PostgreSQL + PostGIS. Yes.**

- The schema is already PostGIS-committed: `geometry(MultiPolygon, 4326)` is a PostGIS type. Changing engines means replacing this type, losing `ST_IsValid`, GIST spatial indexes, and all geographic query operators.
- Complex DB CHECK constraints — enum pairing (`activity_type`/`storage_duration_tier`) and date rules (`PERMANENT_REMOVAL` null ends, monitoring covering activity period) — require Postgres-level constraint expressiveness. No alternative matches this without moving logic into the application.
- Relational FK chain (`projects → activities`) with non-nullable keys is the design intent; it stays in the DB where it belongs.
- Elixir/Phoenix/Ecto: first-class Postgres adapter plus `geo_postgis` for geometry type mapping — actively maintained, production-validated combination.
- Single-tenant, no time-series: no distributed or columnar engine justified.

**Alternatives dismissed:**

| Engine | Dismissal |
|---|---|
| MySQL / MariaDB | Spatial extensions exist but PostGIS is categorically superior; `ST_IsValid`, SRID-aware transforms, and GIST indexing are not equivalent |
| CockroachDB | PostGIS support is partial and lagging; adds distributed overhead for zero single-tenant benefit |
| SQLite + SpatiaLite | No production Ecto adapter for spatial; not appropriate for server deployment |
| MongoDB | Document model drops relational guarantees; geospatial limited to 2D sphere, no polygon validity enforcement |
| TimescaleDB | Postgres extension for time-series; no workload here that warrants it |

