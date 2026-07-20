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

# ── TimescaleDB apt repo ───────────────────────────────────────────────────────
RUN curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ noble main" \
       > /etc/apt/sources.list.d/timescaledb.list

# ── PostgreSQL ─────────────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       postgresql-15 \
       postgresql-15-postgis-3 \
       timescaledb-2-postgresql-15 \
    && rm -rf /var/lib/apt/lists/*

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
# shared_preload_libraries must be set before the first cluster start —
# TimescaleDB requires it to register its background worker on startup.
RUN mkdir -p "$PGDATA" \
    && chown runner:runner "$PGDATA" \
    && chmod 700 "$PGDATA" \
    && su -s /bin/bash -c "/usr/lib/postgresql/15/bin/initdb -D '$PGDATA' --username=postgres --no-locale --encoding=UTF8" runner \
    && echo "shared_preload_libraries = 'timescaledb'" >> "$PGDATA/postgresql.conf"

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
