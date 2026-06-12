# Development Environment Setup

Tooling and Databases are managed by [devenv](https://devenv.sh/)

## 1. Install Nix and devenv

```bash
# Install Nix
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install

# Install devenv
nix-env --install --attr devenv -f https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable
```

## 2. Install direnv

direnv loads the devenv environment automatically on `cd`, so you never need to run `devenv shell`.

```bash
# macOS
brew install direnv

# Linux / Nix
nix-env --install --attr direnv -f https://github.com/NixOS/nixpkgs/tarball/nixpkgs-unstable
```

Hook it into your shell, then allow the project's `.envrc`:

```bash
# zsh
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc && source ~/.zshrc

# bash
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc && source ~/.bashrc
```

```bash
direnv allow
```

This builds the environment on first run (Erlang, Elixir, Node.js — a few minutes). After that, `mix`, `elixir`, and `node` are on your PATH whenever you're in the repo. If direnv isn't active for any reason, run `devenv shell` instead.

## 3. Install inotify-tools (Linux only)

Required for live-reload in development:

```bash
# Debian / Ubuntu
sudo apt-get install inotify-tools
```

## 4. Start services

`devenv up` starts all services defined in `devenv.nix`. Use `-d` to run them in the background:

```bash
#start all services in background
devenv up -d

#shutdown
devenv processes down
```

### Notes

PostgreSQL listens on a Unix socket on port `5433` (`PGHOST`/`PGPORT` are exported by devenv — no TCP password needed).

## Troubleshooting

**Database connection refused** — ensure `devenv up -d` is running and the direnv environment is loaded (`PGHOST`/`PGPORT` must be set). Re-run `direnv allow` if the environment didn't load.
