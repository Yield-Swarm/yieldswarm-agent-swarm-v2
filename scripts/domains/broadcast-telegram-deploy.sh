#!/usr/bin/env bash
# §6 — Broadcast yieldswarm.blockchain IPFS deploy to Telegram.
# Reads TELEGRAM_BOT_TOKEN + TELEGRAM_YIELDSWARM_CHAT_ID (and optional TELEGRAM_COUNCIL_CHAT_ID).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="${ROOT}/config/deployments/BLOCKCHAIN-IPFS-DEPLOY-001.json"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '[telegram-broadcast] %s\n' "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

# ── env: sovereign broadcast credentials (Vault-injected in production) ──
TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_YIELD="${TELEGRAM_YIELDSWARM_CHAT_ID:-}"
CHAT_COUNCIL="${TELEGRAM_COUNCIL_CHAT_ID:-}"

CID="${YIELDSWARM_BLOCKCHAIN_CID:-}"
HELIX="${HELIX_DEPLOY_RECEIPT:-}"
RUN_ID="${YIELDSWARM_BLOCKCHAIN_RUN_ID:-}"
DOMAIN="${YIELDSWARM_BLOCKCHAIN_DOMAIN:-yieldswarm.blockchain}"

load_manifest() {
  [[ -f "$MANIFEST" ]] || return 0
  local py='import json,sys; m=json.load(open(sys.argv[1]))'
  [[ -n "$CID" ]]    || CID="$(python3 -c "$py; print(m['ipfs']['cidV0'])" "$MANIFEST")"
  [[ -n "$HELIX" ]]   || HELIX="$(python3 -c "$py; print(m['helix']['hmacReceipt'])" "$MANIFEST")"
  [[ -n "$RUN_ID" ]]  || RUN_ID="$(python3 -c "$py; print(m['runId'])" "$MANIFEST")"
  [[ -n "$DOMAIN" ]]  || DOMAIN="$(python3 -c "$py; print(m['domain'])" "$MANIFEST")"
}

validate_env() {
  [[ -n "$TOKEN" ]] || die "TELEGRAM_BOT_TOKEN not set (Vault path or .env)"
  [[ -n "$CHAT_YIELD$CHAT_COUNCIL" ]] || die \
    "Configure TELEGRAM_YIELDSWARM_CHAT_ID and/or TELEGRAM_COUNCIL_CHAT_ID"
  [[ -n "$CID" ]] || die "IPFS CID missing — set YIELDSWARM_BLOCKCHAIN_CID or deploy manifest"
  [[ -n "$HELIX" ]] || die "HELIX receipt missing — set HELIX_DEPLOY_RECEIPT or deploy manifest"
}

build_message() {
  cat <<EOF
yieldswarm.blockchain DEPLOYED

Domain: ${DOMAIN}
IPFS CID: ${CID}
HELIX: logged (${HELIX})

Run: ${RUN_ID:-BLOCKCHAIN-IPFS-DEPLOY-001}
EOF
}

send_to_chat() {
  local chat_id="$1"
  local label="$2"
  local text="$3"
  local response http_code body

  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would send to ${label} (${chat_id})"
    return 0
  fi

  body="$(mktemp)"
  trap 'rm -f "$body"' RETURN

  http_code="$(
    curl -fsS -o "$body" -w '%{http_code}' \
      --connect-timeout 15 --max-time 45 \
      -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
      -d "chat_id=${chat_id}" \
      --data-urlencode "text=${text}" \
      2>/dev/null || echo "000"
  )"

  if [[ "$http_code" != "200" ]]; then
    response="$(cat "$body" 2>/dev/null || true)"
    die "Telegram API failed for ${label} (HTTP ${http_code}): ${response:-curl error}"
  fi

  log "Sent to ${label} (chat ${chat_id})"
  log "HELIX confirmation logged: ${HELIX}"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help)
        cat <<'EOF'
Usage: broadcast-telegram-deploy.sh [--dry-run]

Environment:
  TELEGRAM_BOT_TOKEN           Bot token from @BotFather
  TELEGRAM_YIELDSWARM_CHAT_ID  YieldSwarm AI group chat ID
  TELEGRAM_COUNCIL_CHAT_ID     Council group chat ID (optional)
  YIELDSWARM_BLOCKCHAIN_CID    Override CID (default: deploy manifest)
  HELIX_DEPLOY_RECEIPT         Override HELIX HMAC (default: manifest)
EOF
        exit 0
        ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  load_manifest
  validate_env

  local msg
  msg="$(build_message)"
  log "Broadcasting deploy for ${DOMAIN} | CID ${CID}"

  [[ -n "$CHAT_YIELD" ]] && send_to_chat "$CHAT_YIELD" "YieldSwarm AI" "$msg"
  [[ -n "$CHAT_COUNCIL" ]] && send_to_chat "$CHAT_COUNCIL" "Council" "$msg"

  log "Broadcast complete"
}

main "$@"
