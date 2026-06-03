# Contributing to `livedata`

`livedata` is the Phoenix application of this monorepo.

Before contributing, read the repository guidelines:

- [General guidelines](../docs/contributing/general.md) — ground rules,
  requirement traceability, source of truth.
- [Elixir/Phoenix guidelines](../docs/contributing/elixir.md) — development
  environment, how to run this app, and conventions.

## Quick start

From the repo root, enter the devenv shell (provides the toolchain and a
PostgreSQL service), then work inside this directory:

```
devenv shell
cd livedata
mix setup
mix phx.server
```
