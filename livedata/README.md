# Livedata

The Phoenix application of this monorepo.

## Running the app

The toolchain and a PostgreSQL service are provided by
[devenv](https://devenv.sh/) at the repo root and loaded automatically via
direnv when you enter the directory. First-time environment setup (including
starting PostgreSQL) is covered in [`SETUP.md`](../SETUP.md).

Once the environment is up, from this directory:

```bash
mix setup           # install deps + set up assets and the database
mix phx.server      # http://localhost:4000
# or inside IEx:
iex -S mix phx.server
```

Other common tasks:

```bash
mix test            # run the test suite
mix ecto.migrate    # run migrations
mix format          # format code before committing
```

## Contributing

Coding guidelines for this app (Elixir/Phoenix/Ecto/LiveView conventions) live
in [`docs/contributing/livedata.md`](../docs/contributing/livedata.md).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
