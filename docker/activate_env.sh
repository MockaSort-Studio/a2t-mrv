#!/bin/bash
# Start the development environment inside the Hall dispatch container.
# Run this once before the validation loop — mix test handles DB setup from here.
set -e

pg_ctl start -D "$PGDATA" -l /tmp/postgresql.log -o "-p $PGPORT -k $PGHOST"
until pg_isready -h "$PGHOST" -p "$PGPORT" -U postgres 2>/dev/null; do sleep 0.2; done

git config --global core.hooksPath .githooks
