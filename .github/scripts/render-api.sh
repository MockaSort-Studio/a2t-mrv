#!/usr/bin/env bash
# Thin wrapper around the Render REST API, sourced by
# .github/workflows/preview.yml. Not executable on its own.
#
#   render_api METHOD PATH [JSON_BODY]   # any non-2xx fails the step
#
# PATH is relative to https://api.render.com/v1. The response body goes to
# stdout so callers can pipe it to jq; on failure it goes to stderr instead,
# because Render answers a rejected field with a 400 and an explanatory body
# that `curl --fail` would throw away — and a swallowed body here reads as an
# unexplained CI failure.

render_api() {
  local method="$1" path="$2" body="${3-}"

  local args=(
    --silent --show-error
    --request "$method"
    --header "Authorization: Bearer ${RENDER_API_KEY}"
    --header "Accept: application/json"
    --write-out '\n%{http_code}'
  )

  if [ -n "$body" ]; then
    args+=(--header "Content-Type: application/json" --data "$body")
  fi

  local response status payload
  response="$(curl "${args[@]}" "https://api.render.com/v1${path}")"

  # http_code is appended after a final newline, so the last line is the status
  # and everything before it is the body — which may itself span lines.
  status="${response##*$'\n'}"
  payload="${response%$'\n'*}"

  if [[ $status == 2* ]]; then
    printf '%s' "$payload"
    return 0
  fi

  echo "::error::Render API ${method} ${path} returned HTTP ${status}" >&2
  echo "$payload" >&2
  return 1
}
