# CI runner environment for Hall automata dispatched against this repository.
#
# Extends the shared Hall base image (Node.js, gh CLI, git, jq, yq, runner user)
# with Elixir/OTP and PostgreSQL for the mix validation loop.
#
# Multi-stage build: Elixir/OTP copied from the official elixir:1.18-otp-27-slim
# image. The base image is Ubuntu 24.04 (glibc 2.39), matching the GHA runner.
# Elixir/OTP compiled on Debian bookworm (glibc 2.36) is forward-compatible with
# glibc 2.39, so the copy-across works cleanly.
#
# PostgreSQL starts automatically via the entrypoint; no `services:` block is
# needed in any workflow that uses this image as a job container.
#
# Not a development environment — use devenv.nix locally.

FROM elixir:1.18-otp-27-slim AS elixir

# ── Final image: Hall base + repo-specific runtimes ────────────────────────────
FROM ghcr.io/mockasort-studio/hall-dispatch-base-image:latest

# ── OTP runtime dependencies ───────────────────────────────────────────────────
# beam.smp (compiled on Debian bookworm) needs libtinfo, libstdc++, libgcc_s.
# libssl3 is needed by OTP's ssl/crypto apps.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libtinfo6 libstdc++6 libgcc-s1 libssl3 \
    && rm -rf /var/lib/apt/lists/*

# ── Elixir + OTP from official image ──────────────────────────────────────────
COPY --from=elixir /usr/local/lib/erlang /usr/local/lib/erlang
COPY --from=elixir /usr/local/lib/elixir /usr/local/lib/elixir
COPY --from=elixir /usr/local/bin/erl \
                   /usr/local/bin/erlc \
                   /usr/local/bin/escript \
                   /usr/local/bin/run_erl \
                   /usr/local/bin/to_erl \
                   /usr/local/bin/elixir \
                   /usr/local/bin/elixirc \
                   /usr/local/bin/iex \
                   /usr/local/bin/mix \
                   /usr/local/bin/

# ── PGDG apt repo ─────────────────────────────────────────────────────────────
# curl and gnupg are available from the base image.
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list

# ── PostgreSQL ─────────────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       postgresql-15 \
       postgresql-15-postgis-3 \
    && rm -rf /var/lib/apt/lists/*

# ── HashiCorp apt repo ────────────────────────────────────────────────────────
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/hashicorp.gpg \
    && echo "deb [arch=amd64] https://apt.releases.hashicorp.com noble main" \
       > /etc/apt/sources.list.d/hashicorp.list

# ── Terraform (≥ 1.7) + tflint ───────────────────────────────────────────────
# unzip is needed by the tflint install script.
RUN apt-get update \
    && apt-get install -y --no-install-recommends terraform unzip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh \
       | bash

# ── Environment ────────────────────────────────────────────────────────────────
# ERL_LIBS is set in the official elixir image so OTP can locate Elixir's .beam
# files under /usr/local/lib/elixir/lib/. The multi-stage COPY transfers the
# files but not the ENV from the source stage, so we must re-declare it here.
ENV ERL_LIBS=/usr/local/lib/elixir/lib

ENV PATH="/usr/lib/postgresql/15/bin:$PATH"

ENV PGDATA="/var/lib/postgresql/data" \
    PGHOST="/tmp/postgresql" \
    PGPORT="5433" \
    PGUSER="postgres"

# ── Mix tooling ────────────────────────────────────────────────────────────────
# GHA overrides HOME=/github/home at runtime; pin MIX_HOME so hex and rebar
# archives installed here remain on PATH regardless of what HOME becomes.
# /usr/local/share/mix is world-writable so mix works as any user (including
# runner at UID 1001 when the container runs non-root).
ENV MIX_HOME=/usr/local/share/mix
RUN mix local.hex --force && mix local.rebar --force \
    && chmod -R 777 /usr/local/share/mix

# ── PostgreSQL cluster ─────────────────────────────────────────────────────────
# initdb runs as runner (UID 1001) so runner owns the cluster and can start it
# directly in the entrypoint without su. The socket goes to /tmp/postgresql
# which is world-writable, removing the need for any privilege escalation at
# runtime.
RUN mkdir -p "$PGDATA" \
    && chown runner:runner "$PGDATA" \
    && chmod 700 "$PGDATA" \
    && su -s /bin/bash -c "/usr/lib/postgresql/15/bin/initdb -D '$PGDATA' --username=postgres --no-locale --encoding=UTF8" runner

# ── Chrome for Testing + chromedriver ─────────────────────────────────────────
# Version is the single source of truth shared with devenv.nix via chrome-version.
# chrome and chromedriver are always published at the same version by Google.
# To update: change docker/chrome-version; both Dockerfile and devenv.nix follow.
COPY chrome-version /tmp/chrome-version
RUN CHROME_VERSION=$(cat /tmp/chrome-version) \
    && curl -fsSL \
       "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip" \
       -o /tmp/chrome.zip \
    && unzip /tmp/chrome.zip -d /opt \
    && rm /tmp/chrome.zip
RUN CHROME_VERSION=$(cat /tmp/chrome-version) \
    && curl -fsSL \
       "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip" \
       -o /tmp/chromedriver.zip \
    && unzip /tmp/chromedriver.zip -d /tmp/chromedriver-extract \
    && mv /tmp/chromedriver-extract/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
    && chmod +x /usr/local/bin/chromedriver \
    && rm -rf /tmp/chromedriver.zip /tmp/chromedriver-extract

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
