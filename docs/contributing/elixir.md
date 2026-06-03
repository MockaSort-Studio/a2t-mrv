# Elixir / Phoenix contributing guidelines

Technology-specific rules for the Phoenix app under [`livedata/`](../../livedata/).
Cross-cutting rules live in [general.md](general.md).

## Development environment

The toolchain (Elixir, Erlang, Node.js/npm) and a PostgreSQL service are
provided by [devenv](https://devenv.sh/), configured at the repo root in
`devenv.nix`. Enter the shell from the repo root:

```
devenv shell
```

PostgreSQL runs on a Unix socket on port `5433`. Phoenix connects via
`socket_dir`/`PGHOST` with no TCP password — see `livedata/config/dev.exs` and
`livedata/config/test.exs`.

## Running the app

The Phoenix app lives in `livedata/`. Run `mix` tasks from inside that
directory (the devenv shell is entered from the repo root):

```
cd livedata
mix setup            # deps.get + assets setup + ecto.setup
mix ecto.create      # creates livedata_dev / livedata_test
mix phx.server       # serves on http://localhost:4000
mix test
```

## Conventions

- Format code with `mix format` before committing; the formatter config is
  `livedata/.formatter.exs`.
- Modules are namespaced under `Livedata` (domain) and `LivedataWeb` (web).
- Keep requirement traceability `@req:` annotations in code as described in
  [general.md](general.md).
