#!/usr/bin/env bash
# Deploy any PoWUoI coin via SRBMiner-MULTI (when algorithm is supported).
#
# Usage:
#   ./scripts/mining/deploy-srbminer-pouw.sh PRL
#   ./scripts/mining/deploy-srbminer-pouw.sh ZANO --live
#   ./scripts/mining/deploy-srbminer-pouw.sh all --live
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PYTHONPATH="${REPO_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
# shellcheck source=scripts/mining/lib/srbminer-common.sh
source "${REPO_ROOT}/scripts/mining/lib/srbminer-common.sh"

SYMBOL="${1:-PRL}"
shift || true
LIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) LIVE=true; shift ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "${LIVE}" == "true" ]]; then
  export MINING_DRY_RUN=0
fi

deploy_one() {
  local sym="$1"
  if [[ "${sym}" == "PRL" ]]; then
    exec "${REPO_ROOT}/scripts/mining/deploy-pearl-srbminer.sh"
  fi

  local cfg
  cfg="$(python3 - "${sym}" <<'PY'
import json, os, sys
from mining.pouw_registry import list_pouw_coins

sym = sys.argv[1].upper()
coin = next((c for c in list_pouw_coins() if c.symbol == sym), None)
if not coin:
    raise SystemExit(f"unknown coin: {sym}")

data = json.loads(open("config/mining/pouw-coins.json", encoding="utf-8").read())
row = next(r for r in data["coins"] if r["symbol"] == sym)
algo = row.get("srbminer_algorithm", "")
if not algo:
    raise SystemExit(f"{sym} has no srbminer_algorithm — use coin-specific miner")

wallet = coin.wallet()
pool = coin.pool_url()
worker_env = row.get("worker_name_env", f"{sym}_WORKER_NAME")
worker_default = row.get("default_worker_name", f"yieldswarm-{sym.lower()}")
worker = os.environ.get(worker_env, worker_default)
print(json.dumps({
    "symbol": sym,
    "algorithm": algo,
    "pool": pool,
    "wallet": wallet,
    "worker": worker,
}))
PY
)"

  local algorithm pool wallet worker
  algorithm="$(echo "${cfg}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["algorithm"])')"
  pool="$(echo "${cfg}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["pool"])')"
  wallet="$(echo "${cfg}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["wallet"])')"
  worker="$(echo "${cfg}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["worker"])')"

  if [[ -z "${wallet}" ]]; then
    echo "[${sym}] ERROR: wallet not configured" >&2
    return 1
  fi
  if [[ -z "${pool}" ]]; then
    echo "[${sym}] ERROR: pool URL not configured (MINING_POOL_URL_${sym})" >&2
    return 1
  fi

  worker="$(srbminer_sanitize_worker "${worker}")"
  wallet_worker="$(srbminer_wallet_worker "${wallet}" "${worker}")"
  SRB="$(srbminer_resolve_binary)"

  CMD=(
    "${SRB}"
    --algorithm "${algorithm}"
    --pool "${pool}"
    --wallet "${wallet_worker}"
    --password x
    --disable-cpu
  )

  if [[ "${MINING_DRY_RUN:-1}" == "1" || "${MINING_DRY_RUN:-1}" == "true" ]]; then
    echo "[${sym}] DRY_RUN — ${algorithm} @ ${pool}"
    printf '  %q' "${CMD[@]}"
    echo
    return 0
  fi

  chmod +x "${SRB}" 2>/dev/null || true
  echo "[${sym}] starting ${algorithm} @ ${pool}"
  "${CMD[@]}" &
}

if [[ "${SYMBOL}" == "all" ]]; then
  for sym in PRL KRX ZANO QTC IRON TON; do
    deploy_one "${sym}" || true
  done
  wait
else
  deploy_one "${SYMBOL}"
fi
