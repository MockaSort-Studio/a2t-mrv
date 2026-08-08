# Production image for the livedata Phoenix app: a Mix release on a slim Debian
# runner. Build context is livedata/.
#
# This is *not* the same thing as docker/Dockerfile, which is the CI / Hall-agent
# environment image (Elixir + PostgreSQL + PostGIS + TimescaleDB, no application
# source, built with `context: docker`) and is contractually the mirror of the
# devenv development environment — see docs/contributing/general.md. The two
# images have no overlap in purpose and must stay separate.
#
# Versions match the toolchain the repo already builds with (Elixir 1.18 / OTP 27,
# see docker/Dockerfile). Both tags are pinned; refresh them together.
#
#   https://hub.docker.com/r/hexpm/elixir/tags
#   https://hub.docker.com/_/debian/tags?name=bookworm

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.16
ARG DEBIAN_VERSION=bookworm-20260803-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# git is required: the :heroicons dependency is a git dep (see mix.exs).
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
    && mix local.rebar --force

ENV MIX_ENV="prod"

# Dependencies first, so a source-only change does not refetch or recompile them.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Downloads the standalone tailwind and esbuild binaries.
RUN mix assets.setup

COPY priv priv
COPY lib lib

# Compile before building assets, not after: assets/js/app.js imports
# "phoenix-colocated/livedata", which the compiler writes into
# _build/prod/phoenix-colocated/. esbuild resolves it from there via NODE_PATH,
# so it must exist first.
RUN mix compile

COPY assets assets

# Mandatory, not optional: config/prod.exs sets
# cache_static_manifest: "priv/static/cache_manifest.json", and both the
# manifest and priv/static/assets/ are gitignored, so nothing usable ships
# without this step. Tailwind also scans lib/livedata_web (see assets/css/app.css).
RUN mix assets.deploy

# Last, so editing runtime config does not invalidate the compile cache.
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# ── Runner ────────────────────────────────────────────────────────────────────
FROM ${RUNNER_IMAGE} AS final

# ca-certificates is required, not cosmetic: config/runtime.exs sets `ssl: true`
# on the Repo, which under postgrex 0.22 means verify-peer against the OS trust
# store. Without this package, connecting to Neon fails certificate verification.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libstdc++6 openssl libncurses6 locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/livedata ./

USER nobody

# Documentation only. Render injects PORT (10000 by default) and
# config/runtime.exs reads it; nothing here binds 4000 specifically.
EXPOSE 4000

# Plain serve. Migrations are chained ahead of this by the platform start
# command (see render.yaml), which keeps `docker run` locally to just serving.
CMD ["/app/bin/server"]
