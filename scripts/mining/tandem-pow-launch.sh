#!/usr/bin/env bash
# Multi-coin PoW tandem launcher — cloud pods + local edge (env-driven, dry-run safe).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

DRY_RUN="${MINING_DRY_RUN:-1}"
NODE_ID="${MINING_NODE_ID:-Arena_Pod_$(date +%s)}"
PAYOUT="${MINING_PAYOUT_ASSET:-LTC}"
POOL="${MINING_POOL_URL:-rx.unmineable.com:3333}"

declare -A WALLETS=(
  [XMR]="${WALLET_XMR:-}"
  [KAS]="${WALLET_KAS:-}"
  [ZEN]="${WALLET_ZEN:-}"
  [ZEPH]="${WALLET_ZEPH:-}"
  [PYI]="${WALLET_PYI:-}"
  [LTC]="${WALLET_LTC:-}"
  [DOGE]="${WALLET_DOGE:-}"
)

log() { printf '[tandem-pow] %s\n' "$*" >&2; }

[[ -f deploy/env/trident-mainnet.env ]] && set -a && source deploy/env/trident-mainnet.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

WALLET="${WALLETS[$PAYOUT]:-}"
if [[ -z "$WALLET" ]]; then
  log "WARN: WALLET_${PAYOUT} unset — export wallets in deploy/env/trident-mainnet.env"
fi

log "Node: $NODE_ID | Payout: $PAYOUT | Pool: $POOL | dry_run=$DRY_RUN"

if [[ "$DRY_RUN" == "1" ]]; then
  log "Dry-run — set MINING_DRY_RUN=0 to launch xmrig"
  exit 0
fi

ARCH="$(uname -m)"
BIN_DIR="$ROOT/.run/xmrig-core"
if [[ ! -x "$BIN_DIR/xmrig" ]]; then
  mkdir -p "$BIN_DIR"
  case "$ARCH" in
    aarch64|arm64)
      TARBALL="xmrig-6.21.0-linux-arm64.tar.gz"
      ;;
    *)
      TARBALL="xmrig-6.21.0-linux-x64.tar.gz"
      ;;
  esac
  curl -fsSL "https://github.com/xmrig/xmrig/releases/download/v6.21.0/${TARBALL}" \
    | tar -xz -C "$BIN_DIR" --strip-components=1
fi

exec "$BIN_DIR/xmrig" \
  -o "$POOL" \
  -u "${PAYOUT}:${WALLET}.${NODE_ID}" \
  -p x \
  --donate-level=1 \
  --background
