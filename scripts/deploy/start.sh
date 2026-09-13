#!/usr/bin/env bash
# ApplicationStart: bring up the livedata container with the newly pulled image.
# Reads image_ref from the revision to set the LIVEDATA_IMAGE env var for Compose.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
IMAGE_REF=$(cat "$SCRIPT_DIR/image_ref")
DEPLOY_PATH="${DEPLOY_PATH:-/root/a2t-mrv/deploy}"

cd "$DEPLOY_PATH"
LIVEDATA_IMAGE="$IMAGE_REF" docker compose up -d --no-deps livedata
