#!/usr/bin/env bash
# Render fallback deployer (invoked by Terraform null_resource.render).
# Triggers a deploy of the worker image via the Render REST API.
set -euo pipefail

: "${WORKER_IMAGE:?WORKER_IMAGE required}"
: "${RENDER_API_KEY:?RENDER_API_KEY required}"
SERVICE_ID="${RENDER_SERVICE_ID:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="https://api.render.com/v1"

if [[ -z "$SERVICE_ID" ]]; then
  echo "[render] RENDER_SERVICE_ID not set — create a service once, then export it" >&2
  exit 1
fi

echo "[render] deploying ${WORKER_IMAGE} to service ${SERVICE_ID}"
# Point the service at the new image, then trigger a deploy.
curl -fsS -X PATCH "${API}/services/${SERVICE_ID}" \
  -H "Authorization: Bearer ${RENDER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"image\":{\"imagePath\":\"${WORKER_IMAGE}\"}}" >/dev/null

curl -fsS -X POST "${API}/services/${SERVICE_ID}/deploys" \
  -H "Authorization: Bearer ${RENDER_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"clearCache":"do_not_clear"}' >/dev/null

# Resolve the service URL.
URL="$(curl -fsS "${API}/services/${SERVICE_ID}" \
  -H "Authorization: Bearer ${RENDER_API_KEY}" \
  | sed -n 's/.*"serviceDetails":{[^}]*"url":"\([^"]*\)".*/\1/p')"
[[ -n "$URL" ]] && echo "${URL%/}/healthz" > "${HERE}/../fallback-url.txt"
echo "[render] deploy triggered (${URL:-unknown url})"
