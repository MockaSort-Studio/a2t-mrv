#!/usr/bin/env bash
# ValidateService: confirm the livedata endpoint is serving HTTP successfully.
# Reads PHX_HOST from the deploy .env file if not already set in the environment.
# Retries for up to 2 minutes to allow for container startup and migration time.
# A non-zero exit here triggers automatic rollback via the deployment group's
# AutoRollbackConfiguration.
set -euo pipefail

DEPLOY_PATH="${DEPLOY_PATH:-/root/a2t-mrv/deploy}"

if [ -z "${PHX_HOST:-}" ] && [ -f "$DEPLOY_PATH/.env" ]; then
  PHX_HOST=$(grep '^PHX_HOST=' "$DEPLOY_PATH/.env" | cut -d'=' -f2)
fi

: "${PHX_HOST:?PHX_HOST not set — add it to $DEPLOY_PATH/.env or the environment}"

URL="https://${PHX_HOST}/"

for i in $(seq 1 12); do
  STATUS="$(curl -sSo /dev/null -w '%{http_code}' --max-time 10 "$URL" || true)"
  case "$STATUS" in
    2[0-9][0-9]|301|302)
      echo "Health check passed — $URL returned $STATUS."
      exit 0
      ;;
    *)
      echo "Attempt $i/12 — got $STATUS, waiting 10 s..."
      sleep 10
      ;;
  esac
done

echo "Health check failed — $URL did not respond within 2 minutes."
exit 1
