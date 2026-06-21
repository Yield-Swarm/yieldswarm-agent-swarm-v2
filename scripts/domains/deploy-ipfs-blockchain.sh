#!/usr/bin/env bash
# Main orchestrator: verify pinned IPFS CID, confirm HELIX ledger, broadcast Telegram §6.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="${ROOT}/config/deployments/BLOCKCHAIN-IPFS-DEPLOY-001.json"
VERIFY="${ROOT}/scripts/domains/verify-ipfs-cid.sh"
BROADCAST="${ROOT}/scripts/domains/broadcast-telegram-deploy.sh"

SKIP_VERIFY="${SKIP_IPFS_VERIFY:-0}"
SKIP_BROADCAST="${SKIP_TELEGRAM_BROADCAST:-0}"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '[domains:deploy] %s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

load_env() {
  if [[ -f "${ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "${ROOT}/.env"
    set +a
  fi
}

require_manifest() {
  [[ -f "$MANIFEST" ]] || {
    echo "Missing deploy manifest: $MANIFEST" >&2
    exit 1
  }
}

run_verify() {
  if [[ "$SKIP_VERIFY" == "1" ]]; then
    log "SKIP_IPFS_VERIFY=1 — skipping gateway checks"
    return 0
  fi
  step "Verify IPFS CID on public gateways"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] bash $VERIFY"
    return 0
  fi
  bash "$VERIFY"
}

confirm_helix() {
  step "HELIX ledger confirmation"
  local receipt cid domain
  receipt="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['helix']['hmacReceipt'])")"
  cid="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['ipfs']['cidV0'])")"
  domain="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['domain'])")"
  log "Domain: ${domain}"
  log "CID:    ${cid}"
  log "HELIX:  ${receipt}"
  export HELIX_DEPLOY_RECEIPT="${HELIX_DEPLOY_RECEIPT:-$receipt}"
  export YIELDSWARM_BLOCKCHAIN_CID="${YIELDSWARM_BLOCKCHAIN_CID:-$cid}"
}

run_broadcast() {
  if [[ "$SKIP_BROADCAST" == "1" ]]; then
    log "SKIP_TELEGRAM_BROADCAST=1 — skipping Telegram §6"
    return 0
  fi
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    log "TELEGRAM_BOT_TOKEN not set — skip broadcast (configure .env to enable §6)"
    return 0
  fi
  if [[ -z "${TELEGRAM_YIELDSWARM_CHAT_ID:-}${TELEGRAM_COUNCIL_CHAT_ID:-}" ]]; then
    log "No Telegram chat IDs — skip broadcast (set TELEGRAM_YIELDSWARM_CHAT_ID)"
    return 0
  fi
  step "Telegram broadcast (§6)"
  local args=()
  [[ "$DRY_RUN" == "1" ]] && args+=(--dry-run)
  bash "$BROADCAST" "${args[@]}"
}

usage() {
  cat <<'EOF'
Usage: deploy-ipfs-blockchain.sh [--dry-run]

Orchestrates yieldswarm.blockchain IPFS deploy post-pin steps:
  1. Gateway verification (scripts/domains/verify-ipfs-cid.sh)
  2. HELIX receipt log
  3. Telegram broadcast when credentials are configured

Environment:
  SKIP_IPFS_VERIFY=1         Skip gateway curl checks
  SKIP_TELEGRAM_BROADCAST=1  Never send Telegram messages
  DRY_RUN=1                  Print actions without network calls

Telegram (§6):
  TELEGRAM_BOT_TOKEN
  TELEGRAM_YIELDSWARM_CHAT_ID
  TELEGRAM_COUNCIL_CHAT_ID   (optional)
EOF
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
    esac
  done

  load_env
  require_manifest

  echo "================================================================="
  echo "YIELDSWARM.BLOCKCHAIN — IPFS DEPLOY ORCHESTRATOR"
  echo "================================================================="

  run_verify
  confirm_helix
  run_broadcast

  echo "================================================================="
  echo "DEPLOY ORCHESTRATOR FINISHED — see docs/IPFS_YIELDSWARM_BLOCKCHAIN.md"
  echo "================================================================="
}

main "$@"
