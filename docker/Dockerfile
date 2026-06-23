# CI runner environment for Hall automata dispatched against this repository.
#
# Multi-stage build: Elixir/OTP copied from the official elixir:1.18-otp-27-slim
# image into ubuntu:24.04. Ubuntu 24.04 matches the github-hosted runner's glibc
# (2.39), so claude-code-action's native build download works without workarounds
# and always installs the current Claude Code version automatically.
# Elixir/OTP compiled on Debian bookworm (glibc 2.36) is forward-compatible with
# glibc 2.39, so the copy-across works cleanly.
#
# PostgreSQL starts automatically via the entrypoint; no `services:` block is
# needed in any workflow that uses this image as a job container.
#
# Designed to run as UID 1001 (runner). The dispatch workflow must pass
# --user 1001 (or equivalent) in the container options so GHA does not
# override the effective user to root. CC 2.1+ refuses
# --dangerously-skip-permissions as root; running as non-root is the fix.
#
# Not a development environment — use devenv.nix locally.

FROM elixir:1.18-otp-27-slim AS elixir

# ── Final image: ubuntu:24.04 = glibc 2.39, matching the GHA runner ───────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

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

# ── External package repos (Node.js 20, PGDG, GitHub CLI) ─────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt noble-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/githubcli.gpg \
    && echo "deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && rm -rf /var/lib/apt/lists/*

# ── System packages ────────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       nodejs \
       postgresql-15 \
       postgresql-15-postgis-3 \
       gh \
       git \
       jq \
       unzip \
    && rm -rf /var/lib/apt/lists/*

# yq is not in Ubuntu repos; install the Go binary directly
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ── Runner user ────────────────────────────────────────────────────────────────
# UID 1001 matches the github-hosted runner's UID so workspace bind-mounts
# are accessible and CC (which refuses to run as root since 2.1.186) works.
RUN useradd -m -u 1001 -s /bin/bash runner

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

# GHA sets HOME=/github/home; use --system so safe.directory is honoured
# regardless of what HOME the runner injects at container start.
RUN git config --system --add safe.directory '*'

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

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
