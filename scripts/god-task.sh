#!/usr/bin/env bash
# scripts/god-task.sh — Run a single God Task by ID (1-55)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TASKS_JSON="$ROOT/config/god-tasks.json"

usage() {
  echo "Usage: god-task.sh <id|list|status>"
  echo "  god-task.sh 55     Run capstone deploy"
  echo "  god-task.sh 1      Open HQ DePIN dashboard"
  echo "  god-task.sh list   Print all tasks"
}

task_title() {
  node -e "
    const t = require('$TASKS_JSON').find(x => x.id === $1);
    if (t) console.log(t.title);
    else process.exit(1);
  "
}

run_task() {
  local id="$1"
  echo "🌀 God Task #$id: $(task_title "$id")"

  case "$id" in
    1|27|35)
      echo "→ HQ DePIN dashboard: file://$ROOT/dashboard/depin-hq-sync.html"
      echo "→ API: curl -s ${API_BASE:-http://127.0.0.1:8080}/api/arena/overview | head"
      ;;
    10)
      echo "→ HQ splatter assets: assets/hq/README.md"
      echo "→ Import balcony recon photos to assets/hq/ (do not commit SecretProd PDF)"
      ;;
    11)
      echo "→ Tesla mesh: src/infrastructure/entropy-core.js TeslaMeshEntropyCore"
      echo "→ Docs: docs/TESLA_FLEET_INTEGRATION.md"
      ;;
    13|24)
      echo "→ ZK: docs/ZK_ENTROPY_SETUP.md && npm run test:entropy"
      ;;
    16)
      echo "→ Router: src/infrastructure/odysseus-router.js"
      ;;
    19)
      echo "→ Treasury: npm run test:backend -- --test-name-pattern=great-delta"
      ;;
    46)
      echo "→ Bittensor: ./scripts/deploy-bittensor.sh"
      ;;
    48)
      echo "→ SOL rewards: curl -X POST ${API_BASE:-http://127.0.0.1:8080}/api/god-tasks/complete -d '{\"taskId\":$id}'"
      ;;
    49)
      cat "$ROOT/docs/GOD_TASKS_55.md" | head -40
      ;;
    53)
      echo "→ Notion webhook: POST /api/integrations/notion"
      ;;
    55)
      exec "$ROOT/scripts/yieldswarm-deploy.sh" --phase all
      ;;
    *)
      node -e "
        const t = require('$TASKS_JSON').find(x => x.id === $id);
        console.log('Status:', t.status);
        console.log('Code:', (t.code||[]).join(', '));
        console.log('Env:', (t.env||[]).join(', '));
        console.log('SOL reward:', t.rewardSol);
      "
      echo "→ Mark complete: curl -X POST /api/god-tasks/complete -H 'Content-Type: application/json' -d '{\"taskId\":$id}'"
      ;;
  esac
}

list_tasks() {
  node -e "
    require('$TASKS_JSON').forEach(t =>
      console.log(String(t.id).padStart(2,'0'), t.status.padEnd(12), 'P'+t.phase, t.title.slice(0,60))
    );
  "
}

case "${1:-}" in
  list|ls) list_tasks ;;
  status) list_tasks | rg in_progress || true ;;
  ""|-h|--help) usage ;;
  *)
    [[ "$1" =~ ^[0-9]+$ ]] || { usage; exit 1; }
    (( "$1" >= 1 && "$1" <= 55 )) || { echo "ID must be 1-55"; exit 1; }
    run_task "$1"
    ;;
esac
