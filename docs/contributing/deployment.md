# Deploying `livedata/`

How the Phoenix app under [`livedata/`](../../livedata/) is packaged and deployed
as an example instance: a Mix release in a Docker image, run on Render against a
Neon Postgres database. This file is imported by [`CLAUDE.md`](../../CLAUDE.md).
Cross-cutting rules live in [general.md](general.md); Elixir/Phoenix conventions
in [livedata.md](livedata.md).

## Two Dockerfiles, two purposes

They are not interchangeable and neither should be folded into the other.

| | [`docker/Dockerfile`](../../docker/Dockerfile) | [`livedata/Dockerfile`](../../livedata/Dockerfile) |
|---|---|---|
| Purpose | CI runner / Hall-agent environment | Production release |
| Contains | Elixir, PostgreSQL 15, PostGIS, TimescaleDB — **no application source** | the compiled release, no toolchain |
| Build context | `docker/` (see [`env-image.yml`](../../.github/workflows/env-image.yml)) | `livedata/` |
| `CMD` | `tail -f /dev/null` | `/app/bin/server` |

`docker/` is designated by [general.md](general.md) as the mirror of the devenv
development environment, so it must not be repurposed for deployment — and it
could not be anyway: its build context excludes the app entirely.

## Why Postgres is not hosted on Render

Two migrations require extensions:

- `20260617075526_create_projects.exs` — `CREATE EXTENSION postgis`, and a
  `geometry(MultiPolygon, 4326)` column with a GiST index.
- `20260720205727_create_raw_measurements.exs` — `CREATE EXTENSION timescaledb
  CASCADE` and `create_hypertable('raw_measurements', 'measured_at')`.

Render Postgres supports PostGIS but not TimescaleDB, so it cannot run the
migrations. Neon documents both. Neon's TimescaleDB is the Apache-2 subset (no
compression, no continuous aggregates, no retention policies), which is
sufficient: the app uses `create_hypertable` and nothing else. If Neon's
TimescaleDB ever falls short, Tiger Cloud (Timescale's own managed service) is
the drop-in alternative — only `DATABASE_URL` changes.

Before trusting a new database provider, confirm the schema is hostable, against
its **direct** connection string:

```sh
psql "$DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS postgis"
psql "$DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"
psql "$DATABASE_URL" -c "CREATE TABLE probe (id uuid, measured_at timestamptz NOT NULL)"
psql "$DATABASE_URL" -c "SELECT create_hypertable('probe','measured_at')"
psql "$DATABASE_URL" -c "DROP TABLE probe"
```

All five must succeed. `create_hypertable` is the one that fails on providers
that only claim "TimescaleDB compatible".

## Neon specifics

**Use the direct endpoint, not the pooled one.** Neon's pooled hostname
(`...-pooler....neon.tech`) is pgbouncer in transaction mode, which breaks
Postgrex's named prepared statements. Ecto pools connections itself, so the
direct endpoint is the right choice. If the pooled endpoint is ever unavoidable,
the Repo needs `prepare: :unnamed`.

**Strip the query string.** Neon hands out
`postgresql://user:pass@host/dbname?sslmode=require&channel_binding=require`.
Pass only `postgresql://user:pass@host/dbname` as `DATABASE_URL`; TLS is
configured in Elixir (below), not through libpq-style URL parameters that Ecto's
parser does not interpret.

**TLS is enabled in code.** `config/runtime.exs` sets `ssl: true` on
`Livedata.Repo`. Under postgrex 0.22 that means verify-peer against the
operating system trust store, which is correct for Neon's public CA — and is why
the runner stage of `livedata/Dockerfile` installs `ca-certificates`. A provider
with a private CA would need `ssl: [cacertfile: "..."]`. The `ssl: true` line
ships commented out by the Phoenix generator; do not comment it back out.
`Livedata.Release` also starts `:ssl` explicitly before migrating — without it,
`bin/migrate` hangs rather than failing, because `Application.load/1` does not
start `:ssl` the way booting the endpoint would.

Neon's free compute suspends after roughly five minutes idle. The first request
after a quiet period is slow, and one `DBConnection` disconnect may be logged as
the pool reconnects. That is expected for an example deployment.

## The release

[`livedata/mix.exs`](../../livedata/mix.exs) declares a `livedata` release with
the default `steps: [:assemble]`. Assets are built by an explicit
`mix assets.deploy` in the Dockerfile rather than by an `:assets` release step,
so the asset build stays visible where the image is defined.

Three overlay scripts in [`livedata/rel/`](../../livedata/rel/) land in the
release's `bin/`: `server` (sets `PHX_SERVER=true`, which is what makes a release
start the HTTP listener), `migrate`, and `seed`. A fourth, `start`, chains all
three and is what the platform runs. They must stay mode `755` in git — check
with `git ls-files -s livedata/rel`.

`bin/seed` runs `priv/repo/seeds.exs` on **every** boot, so that script has to
stay re-runnable: guard inserts with `Repo.exists?/1` or an upsert, never a bare
`insert!`. Today it seeds nothing and the step is a no-op — it is chained in from
the start because a reference table that forms depend on cannot be created by a
migration and then left to a human to populate on every new database, and the
failure mode when that is forgotten is a form rendering an empty picker rather
than anything that looks like a deployment problem.

## Environment variables

| Variable | Where it comes from | Notes |
|---|---|---|
| `DATABASE_URL` | Neon dashboard | Direct endpoint, query string stripped. Entered by hand (`sync: false`). |
| `PHX_HOST` | Render, once the service exists | The bare `<service>.onrender.com` hostname — no scheme, no trailing slash (see below). **Must** be set: `runtime.exs` otherwise defaults to `example.com` and generates wrong absolute URLs. Entered by hand. |
| `SECRET_KEY_BASE` | `mix phx.gen.secret` | At least 64 bytes (see below). Rotating it logs every session out. Entered by hand (`sync: false`). |
| `POOL_SIZE` | `render.yaml`, `5` | Below `runtime.exs`'s default of 10; Neon's free tier caps connections. |
| `PORT` | injected by Render | Do not set. `runtime.exs` reads it, defaulting to 4000. |
| `PHX_SERVER` | set by `bin/server` | Do not set. |
| `ECTO_IPV6` | unset | Neon publishes A records; only needed on IPv6-only networks. |

### `SECRET_KEY_BASE` cannot come from Render's `generateValue`

Render's `generateValue: true` produces a 256-bit base64 value — 44 characters.
Plug's cookie session store requires at least 64 bytes and raises on the first
request that touches a session:

```
** (ArgumentError) cookie store expects conn.secret_key_base to be at least 64 bytes
```

The endpoint starts and the log says the application is up, so this only surfaces
when a request arrives. Generate a long enough value instead:

```sh
mix phx.gen.secret          # 64 chars, from livedata/
openssl rand -base64 48     # 64 chars, no Elixir needed
```

### `PHX_HOST` must not include the scheme

`runtime.exs` uses it as `url: [host: host, port: 443, scheme: "https"]`, so the
scheme is already supplied. Setting `PHX_HOST=https://livedata-x.onrender.com`
instead of `livedata-x.onrender.com` leaves the app serving fine behind
`x-forwarded-proto: https`, which makes the mistake easy to miss, but breaks two
things:

- `force_ssl` redirects any request that arrives without
  `x-forwarded-proto: https` to `https://https://<host>/`. The platform proxy
  cannot follow that and answers with its own 500 — which looks like an
  application error but is not one.
- `check_origin` compares the LiveView websocket's `Origin` against the
  configured host, so pages render but nothing interactive connects.

The endpoint logs the parsed value at boot — `Access LivedataWeb.Endpoint at
https://[https://...]` is the tell.

## Building and running locally

From `livedata/`:

```sh
docker build -t livedata:local .
docker run --rm -p 4000:4000 \
  -e DATABASE_URL="postgresql://user:pass@host/dbname" \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e PHX_HOST=localhost \
  livedata:local /app/bin/start
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:4000/   # expect 200
```

Reach it through `localhost`, not the container IP: `config/prod.exs` sets
`force_ssl` with `exclude: [hosts: ["localhost", "127.0.0.1"]]`, which is what
keeps a plain-HTTP request from becoming a 301 redirect loop.

The `/app/bin/start` argument overrides the image's `CMD` so migrations run;
without it the container only serves.

### If the container exits at boot with `eafnosupport`

```
failed_to_start_child, listener, eafnosupport
```

`config/runtime.exs` binds `ip: {0, 0, 0, 0, 0, 0, 0, 0}` — the IPv6 wildcard,
which is the Phoenix default and accepts IPv4 through v4-mapped addresses. A host
or container runtime with IPv6 disabled outright cannot create that socket and
the endpoint fails to start, taking the whole release down. The fix is to bind
the IPv4 wildcard instead:

```elixir
ip: {0, 0, 0, 0}
```

Worth knowing before reading a failed first deploy as a configuration problem:
the same message appears whether the platform lacks IPv6 or the port is wrong.

## Render service

The blueprint is [`render.yaml`](../../render.yaml) at the repository root. It
declares one Docker web service and no database.

1. Create the service from the blueprint (Render → New → Blueprint), or create a
   Docker web service by hand with **Root Directory** `livedata`, **Dockerfile
   Path** `./Dockerfile`, **Docker Build Context Directory** `.`, and **Docker
   Command** `/app/bin/start` — the dashboard equivalents of the blueprint keys,
   which is the fallback if the blueprint's path interpretation misbehaves.
2. Set `DATABASE_URL` and `PHX_HOST` in the dashboard.
3. Deploy, and confirm in the log that `mix assets.deploy` ran during the build
   and that migrations applied on boot.

There is no `healthCheckPath`, deliberately: `force_ssl` answers an internal
HTTP health check with a 301, which Render reads as a failure. Without one,
Render considers the instance live once it is listening. Adding one later means
adding a `/health` route *and* uncommenting `paths: ["/health"]` in
`config/prod.exs`'s `force_ssl` `:exclude` — both, or it 301s.

On the free plan the service spins down after 15 minutes idle and a BEAM release
cold-starts in roughly a minute. Starter removes the spin-down.

To verify a deployment end to end, register a project through the UI: that
exercises a PostGIS write and read, since the map on `/` renders the stored
polygon via `GeoJSON.encode_geometry`.
