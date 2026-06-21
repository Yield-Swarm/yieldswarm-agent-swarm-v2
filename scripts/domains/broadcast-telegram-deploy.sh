#!/usr/bin/env bash
# Broadcast yieldswarm.blockchain IPFS deploy to Telegram (§6).
# Requires TELEGRAM_BOT_TOKEN and TELEGRAM_YIELDSWARM_CHAT_ID (and/or TELEGRAM_COUNCIL_CHAT_ID).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="${ROOT}/config/deployments/BLOCKCHAIN-IPFS-DEPLOY-001.json"

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_YIELD="${TELEGRAM_YIELDSWARM_CHAT_ID:-}"
CHAT_COUNCIL="${TELEGRAM_COUNCIL_CHAT_ID:-}"

CID="${YIELDSWARM_BLOCKCHAIN_CID:-}"
HELIX="${HELIX_DEPLOY_RECEIPT:-}"

if [[ -f "$MANIFEST" ]]; then
  [[ -n "$CID" ]] || CID="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['ipfs']['cidV0'])")"
  [[ -n "$HELIX" ]] || HELIX="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['helix']['hmacReceipt'])")"
fi

[[ -n "$TOKEN" ]] || { echo "TELEGRAM_BOT_TOKEN not set"; exit 1; }
[[ -n "$CHAT_YIELD$CHAT_COUNCIL" ]] || {
  echo "Configure TELEGRAM_YIELDSWARM_CHAT_ID and/or TELEGRAM_COUNCIL_CHAT_ID"
  exit 1
}

MSG="yieldswarm.blockchain DEPLOYED | IPFS: ${CID} | HELIX: logged (${HELIX:0:16}…)"

send() {
  local chat="$1"
  curl -fsS -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d "chat_id=${chat}" \
    --data-urlencode "text=${MSG}" >/dev/null
  echo "Sent to chat ${chat}"
}

[[ -n "$CHAT_YIELD" ]] && send "$CHAT_YIELD"
[[ -n "$CHAT_COUNCIL" ]] && send "$CHAT_COUNCIL"
