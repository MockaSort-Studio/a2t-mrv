# Development Environment Setup

This guide will get you from a fresh clone to a running development server.

The repository is a monorepo: tooling and the PostgreSQL service are managed by
[devenv](https://devenv.sh/) at the root, and the Phoenix application lives in
[`livedata/`](livedata/).

## Prerequisites

### 1. Install devenv

Follow steps 1 and 2 from [devenv Getting Started](https://devenv.sh/getting-started/):

```bash
# Step 1: Install the Nix package manager (if you don't have it)
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install

# On macOS, optionally install a recent version of Bash:
nix-env --install --attr bashInteractive -f https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable

# Step 2: Install devenv
nix-env --install --attr devenv -f https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable
```

### 2. Install direnv

direnv automatically loads the devenv environment when you `cd` into the
project, so you never have to run `devenv shell` by hand.

```bash
# macOS
brew install direnv

# Or via Nix
nix-env --install direnv
```

Add the direnv hook to your shell config:

```bash
# For zsh (~/.zshrc)
eval "$(direnv hook zsh)"

# For bash (~/.bashrc)
eval "$(direnv hook bash)"
```

Restart your shell after adding the hook.

## Setup

### 1. Clone and enter the project

```bash
git clone <repo-url> a2t-mrv
cd a2t-mrv
```

direnv detects the `.envrc` and asks you to allow it:

```bash
direnv allow
```

This triggers devenv to build the environment. The first run downloads and
builds Erlang, Elixir, and Node.js — this takes a few minutes. Subsequent
entries are instant. The `.envrc` is just two lines:

```bash
eval "$(devenv direnvrc)"
use devenv
```

### 2. Start PostgreSQL

The PostgreSQL service is defined in the root `devenv.nix`. Start it (and any
other devenv services) with:

```bash
devenv up -d        # detached; omit -d to run in the foreground
```

It listens on a Unix socket on port `5433` (devenv exports `PGHOST`/`PGPORT`),
so no TCP host or password is needed.

### 3. Set up and run the app

Work inside the `livedata/` directory:

```bash
cd livedata
mix setup           # deps.get + assets setup + ecto.setup
mix ecto.create     # creates livedata_dev / livedata_test
```

Start the server with an interactive shell:

```bash
iex -S mix phx.server
```

The app is served at [`localhost:4000`](http://localhost:4000).

## What devenv provides

You don't need to install Erlang, Elixir, or Node.js manually. devenv manages:

- **Erlang** and **Elixir**
- **Node.js** and **npm** (for the asset pipeline)
- **Hex and Rebar** (installed automatically on shell entry)
- **PostgreSQL** on a Unix socket, port `5433`

## Running tests

From the `livedata/` directory:

```bash
mix test
```

## Troubleshooting

### `direnv: error .envrc is blocked`

Run `direnv allow` to trust the `.envrc` file.

### Database connection refused

Make sure the PostgreSQL service is running (`devenv up -d`) and that you are
inside the direnv-loaded environment (so `PGHOST`/`PGPORT` are set). Run
`direnv allow` again if the environment did not load on `cd`.
