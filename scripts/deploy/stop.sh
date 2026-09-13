#!/usr/bin/env bash
# ApplicationStop: gracefully stop the livedata container before a new revision
# is installed. Tolerates failure if the container is not currently running.
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/root/a2t-mrv/deploy}"

cd "$DEPLOY_PATH"
docker compose stop livedata || true
