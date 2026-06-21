#!/usr/bin/env bash
# deploy-dual.sh — Deploy swarm-flux-miner (H100) + backend (CPU) Akash leases
#
# Usage:
#   ./akash/deploy-dual.sh              # deploy both (dry-run if DRY_RUN=1)
#   ./akash/deploy-dual.sh miner        # H100 only
#   ./akash/deploy-dual.sh backend      # CPU backend only
#   DRY_RUN=1 ./akash/deploy-dual.sh    # validate without chain tx
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN="${DRY_RUN:-0}"
TARGET="${1:-all}"

deploy_one() {
  local profile="$1"
  local extra=()
  case "$profile" in
    miner)
      extra=(--gpu h100 --bid-max 100000uakt)
      ;;
    backend)
      extra=(--bid-max 1500uakt)
      ;;
    *)
      echo "Unknown profile: $profile" >&2
      return 1
      ;;
  esac
  if [[ "$DRY_RUN" == "1" ]]; then
    extra+=(--dry-run)
  fi
  echo "==> Deploying $profile ..."
  python3 "$SCRIPT_DIR/lease-manager.py" --deploy "$profile" "${extra[@]}"
}

case "$TARGET" in
  all)
    deploy_one miner
    deploy_one backend
    python3 "$SCRIPT_DIR/lease-manager.py" --leases
    ;;
  miner|backend)
    deploy_one "$TARGET"
    ;;
  status|leases)
    python3 "$SCRIPT_DIR/lease-manager.py" --leases
    ;;
  *)
    echo "Usage: $0 [all|miner|backend|status]" >&2
    exit 1
    ;;
esac

echo ""
echo "Monitor:"
echo "  python3 akash/lease-manager.py --leases"
echo "  akash query deployment get --owner \$AKASH_ACCOUNT_ADDRESS --dseq <DSEQ>"
