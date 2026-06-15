#!/usr/bin/env bash
# Fly.io fallback deployer (invoked by Terraform null_resource.fly).
# Deploys the worker image as a Fly app and records the public URL.
set -euo pipefail

: "${WORKER_IMAGE:?WORKER_IMAGE required}"
: "${FLY_API_TOKEN:?FLY_API_TOKEN required}"
FLY_REGION="${FLY_REGION:-iad}"
APP="${FLY_APP:-yieldswarm-worker}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export FLY_API_TOKEN
if ! command -v flyctl >/dev/null 2>&1; then
  echo "[fly] flyctl not installed — install from https://fly.io/docs/flyctl/install/" >&2
  exit 1
fi

echo "[fly] deploying ${WORKER_IMAGE} to app ${APP} (${FLY_REGION})"
flyctl apps create "$APP" --machines 2>/dev/null || true
flyctl deploy \
  --app "$APP" \
  --image "$WORKER_IMAGE" \
  --regions "$FLY_REGION" \
  --ha=false \
  --now

URL="https://${APP}.fly.dev/healthz"
echo "$URL" > "${HERE}/../fallback-url.txt"
echo "[fly] live at ${URL}"
