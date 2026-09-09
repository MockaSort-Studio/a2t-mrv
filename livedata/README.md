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

The e2e suite requires `chromedriver` and a Chromium/Chrome browser on `PATH`.

**Linux (devenv):** both are provided by the devenv shell. Enter `devenv shell`
(or `cd` into the repo with direnv enabled) and both will be on `PATH` — no
separate install needed.

**macOS (devenv):** `chromedriver` is provided by the devenv shell. `pkgs.chromium`
is Linux-only in nixpkgs, so you must supply a browser separately. Wallaby looks
for `google-chrome`, `chromium`, or `chromium-browser` on `PATH` — a standard
`/Applications/Google Chrome.app` install does not add any of these. Options:

```bash
# Option A — symlink the system Chrome binary to a name Wallaby recognises:
sudo ln -sf "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    /usr/local/bin/google-chrome

# Option B — install Chromium via Homebrew (adds 'chromium' to PATH):
brew install --cask chromium
```

```bash
mix test --only e2e    # run browser tests against a running Phoenix server
```

`mix test` (without the flag) skips e2e tests so the existing suite runs on any
machine, with or without a browser.

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
