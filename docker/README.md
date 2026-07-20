# docker/

## Why this exists

Hall automata dispatched against this repository need to run a validation loop — compile the code, run migrations, execute the test suite — before opening a pull request. That requires a self-contained runner environment with Elixir/Mix, a live PostgreSQL instance (with PostGIS), Node.js for MCP server tooling, and automation utilities (`gh`, `jq`, `yq`).

The `devenv.nix` file covers local development. This image is the CI counterpart: purpose-built for agent dispatch, independent of Nix, and usable as a job `container:` in any GitHub Actions workflow without a `services:` block. PostgreSQL initialises and starts automatically via the entrypoint before the first workflow step runs.

## Why not devenv containers?

devenv can build OCI images via `devenv container build`, but the approach proved unworkable for GitHub Actions use:

- **FHS incompatibility.** Nix containers use the Nix store layout, not the standard Linux FHS. GitHub Actions mounts host binaries (Node.js, the runner itself) into the container at `/__e`; those binaries are glibc-compiled and expect `/lib64` and standard library paths that don't exist in a Nix container. The workaround — a `fhs-compat` derivation that symlinks every needed `.so` into `/lib64` — was brittle and grew with each new host binary dependency.

- **Slow cluster initialisation.** devenv configures PostgreSQL via its `services.postgres` option, which initialises the cluster at shell-entry time. In a container job this means `initdb` runs at container startup, adding 15+ seconds before the database is ready — after GHA has already started executing steps.

- **Leaky dev config.** Supporting the container required conditional blocks (`lib.optionals (config.containers.ci.isBuilding or false) [...]`) throughout `devenv.nix`, coupling the local development config to CI build-time concerns.

A conventional Dockerfile solves all three: standard FHS layout, `initdb` baked in at image build time (so startup is just `pg_ctl start`, ~1.4 s), and zero impact on `devenv.nix`.

## Image

```
ghcr.io/mockasort-studio/a2t-mrv-env:latest
```

Built and pushed automatically on push to `main` when `docker/Dockerfile` changes, via `.github/workflows/env-image.yml`.

## Contents

| Tool | Version | Purpose |
|------|---------|---------|
| Elixir / OTP | 1.18 / 27 | Mix tasks, compilation, tests |
| PostgreSQL | 15 | Application database |
| PostGIS | 3 | Geospatial extension |
| TimescaleDB | 2 | Time-series extension |
| Node.js | 20 LTS | `npx` / MCP server tooling |
| gh | latest | GitHub API automation |
| git, jq, yq | latest | Automation utilities |

## TimescaleDB

TimescaleDB is installed and preloaded in the cluster (`shared_preload_libraries = 'timescaledb'`). To activate it in a database, run:

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

For automata dispatch: `mix ecto.setup` (or the migration step in `activate_env.sh`) will enable the extension automatically if the migration includes `execute "CREATE EXTENSION IF NOT EXISTS timescaledb"`.

The extension is loaded at cluster startup — no manual `pg_ctl` restart is required inside the container.
