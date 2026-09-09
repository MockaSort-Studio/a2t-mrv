# Livedata

The Phoenix application.

## Running the app

The toolchain and a PostgreSQL service are provided by
[devenv](https://devenv.sh/) at the repo root and loaded automatically via
direnv when you enter the directory. 

First-time environment setup (including starting services) is covered in [`SETUP.md`](../SETUP.md).

```bash
mix setup           # install deps + set up assets and the database
mix phx.server      # http://localhost:4000
# or inside IEx:
iex -S mix phx.server
```

Other common tasks:

```bash
mix test            # run the test suite (browser tests excluded)
mix ecto.migrate    # run migrations
mix format          # format code before committing
```

## End-to-end tests

The e2e suite requires `chromedriver` and a Chrome browser. The devenv shell
provides both from Chrome for Testing (the same pinned version) on Linux and
macOS — enter `devenv shell` (or `cd` into the repo with direnv enabled) and
both are ready, no separate install needed.

The browser binary is exposed via the `CHROME_BINARY` environment variable set
by devenv. Wallaby should be configured to use it with
`binary: System.get_env("CHROME_BINARY")` in `config/test.exs`.

```bash
mix test --only e2e    # run browser tests against a running Phoenix server
```

`mix test` (without the flag) skips e2e tests so the existing suite runs on any
machine.

## Example deployment (temporary)

`Dockerfile` packages the app as a Mix release for a temporary example instance
on Render. It is **not** the development environment — development uses
devenv and Nix. For setup, configuration, and environment variables see
[`docs/contributing/deployment.md`](../docs/contributing/deployment.md).

## Contributing

Coding guidelines for this app (Elixir/Phoenix/Ecto/LiveView conventions) live
in [`docs/contributing/livedata.md`](../docs/contributing/livedata.md).

## Dockerfile — temporary deployment only

`livedata/Dockerfile` builds the Mix release image deployed to Render for
platform evaluation. It is **not** used for local development; the devenv shell
(above) is the development environment. The deployment setup is documented in
[`docs/contributing/deployment.md`](../docs/contributing/deployment.md) and is
expected to be temporary.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
