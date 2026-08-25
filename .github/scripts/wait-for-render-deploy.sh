#!/usr/bin/env bash
# Polls a Render deploy until it goes live, fails, or times out. Sourced by
# .github/workflows/preview.yml (both the deploy and restore jobs) after
# .github/scripts/render-api.sh, which provides render_api().
#
#   wait_for_render_deploy DEPLOY_ID [TIMEOUT_SECONDS]   # default timeout: 1200s

wait_for_render_deploy() {
  local deploy_id="$1" timeout="${2:-1200}"

  local deadline=$(( SECONDS + timeout ))
  while [ "$SECONDS" -lt "$deadline" ]; do
    local status
    status="$(render_api GET "/services/$RENDER_SERVICE_ID/deploys/$deploy_id" '' | jq -r '.status')"
    case "$status" in
      live)
        echo "Deploy $deploy_id is live."
        return 0
        ;;
      build_failed|update_failed|canceled|pre_deploy_failed)
        echo "::error::Deploy $deploy_id ended as $status."
        return 1
        ;;
      *)
        echo "Deploy $deploy_id is $status — waiting."
        sleep 20
        ;;
    esac
  done

  echo "::error::Deploy $deploy_id did not go live within ${timeout}s."
  return 1
}
