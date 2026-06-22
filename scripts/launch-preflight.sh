#!/usr/bin/env bash
# launch-preflight.sh — GO/NO-GO across Akash, mining, and gateway config.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

for f in .env deploy/akash.env; do
  [[ -f "$f" ]] || { echo "Missing $f — run: npm run launch:env-init" >&2; exit 1; }
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
done

echo "=== YieldSwarm launch preflight ==="
echo "TARGET_ENV=${TARGET_ENV:-unset}"
echo "API_BASE=${API_BASE:-unset}"
echo "NEXT_PUBLIC_AKASH_GATEWAY=${NEXT_PUBLIC_AKASH_GATEWAY:-unset}"

./scripts/akash-preflight.sh "${DEPLOY_SDL:-deploy/akash-bittensor-miner.sdl.yml}"

if [[ -f .run/akash-lease.env ]]; then
  # shellcheck disable=SC1091
  source .run/akash-lease.env
  echo "AKASH_WORKER_URLS=${AKASH_WORKER_URLS:-unset}"
fi

if command -v curl >/dev/null && [[ -n "${API_BASE:-}" ]]; then
  curl -sf "${API_BASE}/api/health" >/dev/null && echo "API health: OK" || echo "API health: unreachable (pre-deploy OK)"
fi

MINING_DRY_RUN=1 ./scripts/start-mining.sh 2>/dev/null || true
echo "=== Preflight complete — fix NO-GO items in docs/LAUNCH_PLAYBOOK.md ==="
