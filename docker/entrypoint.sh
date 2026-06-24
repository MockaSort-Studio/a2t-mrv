#!/bin/bash
set -e

# Create the PostgreSQL socket directory. /tmp/postgresql is used instead of
# /var/run/postgresql so this works without root — any UID can write to /tmp.
mkdir -p "$PGHOST"

# Start postgres. The cluster is owned by runner (initdb ran as runner), so
# pg_ctl works directly with no su/gosu — root is not required.
/usr/lib/postgresql/15/bin/pg_ctl start \
    -D "$PGDATA" -l /tmp/postgresql.log -o "-p $PGPORT -k $PGHOST"

until /usr/lib/postgresql/15/bin/pg_isready \
    -h "$PGHOST" -p "$PGPORT" -U postgres 2>/dev/null; do
    sleep 0.2
done

git config --global core.hooksPath .githooks

exec "$@"
