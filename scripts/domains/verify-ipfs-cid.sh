#!/usr/bin/env bash
# Verify yieldswarm.blockchain IPFS CID is reachable on public gateways.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MANIFEST="${ROOT}/config/deployments/BLOCKCHAIN-IPFS-DEPLOY-001.json"
CID="${YIELDSWARM_BLOCKCHAIN_CID:-}"

# Set in env / Vault — see docs/IPFS_YIELDSWARM_BLOCKCHAIN.md
: "${IPFS_PUBLIC_GATEWAY:?Set IPFS_PUBLIC_GATEWAY}"
: "${IPFS_CLOUDFLARE_GATEWAY:?Set IPFS_CLOUDFLARE_GATEWAY}"
: "${IPFS_PINATA_GATEWAY:?Set IPFS_PINATA_GATEWAY}"

if [[ -z "$CID" && -f "$MANIFEST" ]]; then
  CID="$(python3 -c "import json; print(json.load(open('$MANIFEST'))['ipfs']['cidV0'])")"
fi

[[ -n "$CID" ]] || { echo "CID not set"; exit 1; }

check() {
  local name="$1" base="$2"
  local url="${base%/}/ipfs/${CID}"
  if curl -fsSL --max-time 20 -o /dev/null -w "%{http_code}" "$url" | grep -qE '^(200|301|302)$'; then
    echo "OK  $name"
  else
    echo "FAIL $name"
    return 1
  fi
}

echo "Verifying IPFS CID: $CID"
check public "$IPFS_PUBLIC_GATEWAY"
check cloudflare "$IPFS_CLOUDFLARE_GATEWAY"
check pinata "$IPFS_PINATA_GATEWAY"
echo "Gateway checks complete."
