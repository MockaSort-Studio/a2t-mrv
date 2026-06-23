#!/bin/bash
set -e

# /var/run is often a tmpfs in containers; recreate the socket dir if needed.
mkdir -p "$PGHOST"
chown postgres:postgres "$PGHOST"

# Start postgres and wait until it accepts connections before exec-ing into the
# job command. The cluster is already initialized in the image (see Dockerfile),
# so this takes ~2s instead of the ~15s that initdb would add at runtime.
gosu postgres /usr/lib/postgresql/15/bin/pg_ctl start \
    -D "$PGDATA" -l /tmp/postgresql.log -o "-p $PGPORT -k $PGHOST"
until /usr/lib/postgresql/15/bin/pg_isready -h "$PGHOST" -p "$PGPORT" -U postgres 2>/dev/null; do
    sleep 0.2
done

exec "$@"
