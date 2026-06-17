#!/usr/bin/env bash
# Bootstrap local platform: load .env.local secrets + activate Helix Chain.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f .env.local ]]; then
  echo "Missing .env.local — copy .env.example and fill secrets, or re-run env wiring." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${REPO_ROOT}/deploy/scripts/lib.sh"
load_config

step "Helix Chain activation"
bash "${REPO_ROOT}/scripts/activate-helix.sh" "$@"

step "Platform health"
curl -sf "http://127.0.0.1:${PORT:-8080}/api/health" | head -c 400 || warn "health check pending"
echo ""
curl -sf "http://127.0.0.1:${PORT:-8080}/api/helix/status" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d);console.log('Helix:',j.activated,j.phase,j.readinessScore)})" \
  || true

ok "Local platform bootstrapped — secrets from .env.local (gitignored)"
