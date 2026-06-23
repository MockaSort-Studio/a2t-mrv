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
# GHA container jobs always run as root. CC 2.1+ refuses
# --dangerously-skip-permissions as root, so CC is run via a wrapper that drops
# to a non-root user. See /usr/local/bin/claude and PATH_TO_CLAUDE_CODE_EXECUTABLE.
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
       gosu \
       gh \
       git \
       jq \
       unzip \
    && rm -rf /var/lib/apt/lists/*

# yq is not in Ubuntu repos; install the Go binary directly
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ── Environment ────────────────────────────────────────────────────────────────
# ERL_LIBS is set in the official elixir image so OTP can locate Elixir's .beam
# files under /usr/local/lib/elixir/lib/. The multi-stage COPY transfers the
# files but not the ENV from the source stage, so we must re-declare it here.
ENV ERL_LIBS=/usr/local/lib/elixir/lib

ENV PATH="/usr/lib/postgresql/15/bin:$PATH"

ENV PGDATA="/var/lib/postgresql/data" \
    PGHOST="/var/run/postgresql" \
    PGPORT="5433" \
    PGUSER="postgres"

# GHA sets HOME=/github/home; use --system so safe.directory is honoured
# regardless of what HOME the runner injects at container start.
RUN git config --system --add safe.directory '*'

# ── Mix tooling ────────────────────────────────────────────────────────────────
# GHA overrides HOME=/github/home at runtime; pin MIX_HOME so hex and rebar
# archives installed here remain on PATH regardless of what HOME becomes.
# Use a world-accessible path so mix also works when running as the runner user
# (non-root) inside the claude wrapper.
ENV MIX_HOME=/usr/local/share/mix
RUN mix local.hex --force && mix local.rebar --force \
    && chmod -R 777 /usr/local/share/mix

# ── PostgreSQL cluster ─────────────────────────────────────────────────────────
# initdb at build time so the entrypoint only runs pg_ctl start (~2s).
RUN mkdir -p "$PGDATA" "$PGHOST" \
    && chown postgres:postgres "$PGDATA" "$PGHOST" \
    && chmod 700 "$PGDATA" \
    && su -s /bin/bash -c "/usr/lib/postgresql/15/bin/initdb -D '$PGDATA' --username=postgres --no-locale --encoding=UTF8" postgres

# ── Non-root runner user ───────────────────────────────────────────────────────
# UID 1001 matches the github-hosted runner's UID so workspace bind-mounts
# are accessible. This user is the drop-target in the claude wrapper.
RUN useradd -m -u 1001 -s /bin/bash runner

# ── Claude Code pre-install ────────────────────────────────────────────────────
# CC 2.1.186+ refuses --dangerously-skip-permissions as root. GHA container jobs
# always run as root, so we pre-install CC here and provide a wrapper that drops
# to the runner user before invoking it. The action respects
# PATH_TO_CLAUDE_CODE_EXECUTABLE and skips its own install step entirely.
#
# We use /opt/claude as the install HOME so the binary lands at a stable path
# independent of what HOME GHA injects at runtime.
ENV CC_VERSION=2.1.186
# HOME=/opt/claude prefix only applies to the left side of the pipe; wrap in
# bash -c so HOME is exported into the subshell that runs install.sh.
RUN mkdir -p /opt/claude \
    && HOME=/opt/claude bash -c "curl -fsSL https://claude.ai/install.sh | bash -s -- ${CC_VERSION}" \
    && test -x /opt/claude/.local/bin/claude

COPY claude-wrapper.sh /usr/local/bin/claude
RUN chmod +x /usr/local/bin/claude

# Tell claude-code-action@v1 to use our wrapper instead of installing CC itself.
ENV PATH_TO_CLAUDE_CODE_EXECUTABLE=/usr/local/bin/claude

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
