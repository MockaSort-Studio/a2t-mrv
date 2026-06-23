# CI runner environment for Hall automata dispatched against this repository.
#
# Bundles Elixir/Mix, PostgreSQL + PostGIS, Node.js, and automation utilities
# (gh, jq, yq) so agents can run the mix validation loop without Nix or a
# separate `services:` block in the workflow. PostgreSQL starts automatically
# via the entrypoint; any job that uses this image as its container gets a
# ready database before the first step runs.
#
# Not a development environment — use devenv.nix locally.

FROM elixir:1.18-otp-27-slim

# ── Repository keys and source lists ──────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg curl ca-certificates \
    # PGDG: PostgreSQL 15 + PostGIS 3
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
    && echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    # GitHub CLI
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/githubcli.gpg \
    && echo "deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    # NodeSource: Node.js 20 LTS
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && rm -rf /var/lib/apt/lists/*

# ── System packages ────────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       postgresql-15 \
       postgresql-15-postgis-3 \
       nodejs \
       gh \
       git \
       jq \
       unzip \
    && rm -rf /var/lib/apt/lists/*

# yq is not in Debian repos; install the Go binary directly
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ── Environment ────────────────────────────────────────────────────────────────
# pg_ctl and initdb are in /usr/lib/postgresql/15/bin, not on PATH by default
ENV PATH="/usr/lib/postgresql/15/bin:$PATH"

# Socket-based connection matching the livedata Phoenix config conventions
ENV PGDATA="/var/lib/postgresql/data" \
    PGHOST="/var/run/postgresql" \
    PGPORT="5433" \
    PGUSER="postgres"

# GHA sets HOME=/github/home, so ~/.gitconfig is not /root/.gitconfig.
# Use --system (/etc/gitconfig) so safe.directory is honoured regardless
# of what HOME the runner injects at container start.
RUN git config --system --add safe.directory '*'

# ── Mix tooling ────────────────────────────────────────────────────────────────
# Pre-warm hex and rebar so the first mix call in a workflow does not block
RUN mix local.hex --force && mix local.rebar --force

# ── PostgreSQL cluster ─────────────────────────────────────────────────────────
# Run initdb at image build time so the entrypoint only needs to pg_ctl start
# (~2s) rather than initialize (~15s). Without this, the cluster would not be
# ready before GHA begins executing job steps.
RUN mkdir -p "$PGDATA" "$PGHOST" \
    && chown postgres:postgres "$PGDATA" "$PGHOST" \
    && chmod 700 "$PGDATA" \
    && su -s /bin/bash -c "initdb -D '$PGDATA' --username=postgres --no-locale --encoding=UTF8" postgres

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# tail -f /dev/null keeps the container alive whether or not GHA passes its own
# keepalive command; exec "$@" in the entrypoint replaces it with whatever is
# actually passed, falling back to this default when nothing is.
CMD ["tail", "-f", "/dev/null"]
