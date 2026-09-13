#!/usr/bin/env bash
# BeforeInstall: authenticate with GHCR and pull the new image digest.
# Reads two files placed in the revision by the deploy workflow:
#   image_ref   — full GHCR image reference including SHA tag
#   ghcr_token  — short-lived GitHub token with read:packages scope
# The token is valid for the duration of the workflow run (~10 min), which is
# more than enough for the agent to pull the image immediately after deployment.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IMAGE_REF=$(cat "$SCRIPT_DIR/image_ref")
GHCR_TOKEN=$(cat "$SCRIPT_DIR/ghcr_token")
DEPLOY_PATH="${DEPLOY_PATH:-/root/a2t-mrv/deploy}"

echo "$GHCR_TOKEN" | docker login ghcr.io --username x-access-token --password-stdin
docker image prune -af --filter "until=24h"
cd "$DEPLOY_PATH"
LIVEDATA_IMAGE="$IMAGE_REF" docker compose pull livedata
docker logout ghcr.io
