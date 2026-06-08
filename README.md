# a2t-mrv

Monorepo for the a2t-mrv project. Development tooling and a PostgreSQL service
are managed by [devenv](https://devenv.sh/) at the repo root, loaded
automatically via [direnv](https://direnv.net/) on `cd`.

## Layout

| Path | Contents |
|---|---|
| [`livedata/`](livedata/) | Phoenix application |
| [`docs/`](docs/) | Project documentation, incl. [contributing guidelines](docs/contributing/) |
| `devenv.nix` / `.envrc` | Dev environment (Elixir, Erlang, Node.js, PostgreSQL) |

## Getting started

See [SETUP.md](SETUP.md) for full instructions. In short:

```bash
direnv allow        # loads the devenv shell (first run builds the toolchain)
devenv up -d        # starts PostgreSQL
cd livedata && mix setup && iex -S mix phx.server
```

The app is then served at [`localhost:4000`](http://localhost:4000).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the
[contributing guidelines](docs/contributing/).
