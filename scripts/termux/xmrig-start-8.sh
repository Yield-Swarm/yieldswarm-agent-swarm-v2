#!/usr/bin/env bash
# Termux: 8-slotted XMRig CPU miners in tmux (TCL 10 NXT / TPIT swarm profile).
#
# Usage:
#   export MONERO_WALLET_ADDRESS=48...
#   export TERMUX_DEVICE_PREFIX=TPIT-TERMUX
#   ./scripts/termux/xmrig-start-8.sh
#
# Env:
#   XMRIG_PATH=~/xmrig/build/xmrig
#   MONERO_POOL_URL=pool.supportxmr.com:3333
#   XMRIG_THREADS=2
#   XMRIG_INSTANCES=8
#   XMRIG_HTTP_PORT_BASE=8081
set -euo pipefail

WALLET="${MONERO_WALLET_ADDRESS:-${MINING_ROOT_MONERO:-}}"
POOL="${MONERO_POOL_URL:-pool.supportxmr.com:3333}"
PREFIX="${TERMUX_DEVICE_PREFIX:-TPIT-TERMUX}"
THREADS="${XMRIG_THREADS:-2}"
INSTANCES="${XMRIG_INSTANCES:-8}"
PORT_BASE="${XMRIG_HTTP_PORT_BASE:-8081}"
XMRIG="${XMRIG_PATH:-$HOME/xmrig/build/xmrig}"
SESSION="${XMRIG_TMUX_SESSION:-mining}"

if [[ -z "${WALLET}" ]]; then
  echo "[xmrig] ERROR: set MONERO_WALLET_ADDRESS" >&2
  exit 1
fi

if [[ ! -x "${XMRIG}" ]]; then
  echo "[xmrig] ERROR: XMRig not found at ${XMRIG} — run ./scripts/termux/xmrig-install.sh" >&2
  exit 1
fi

XMRIG_DIR="$(cd "$(dirname "${XMRIG}")" && pwd)"

if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock
  echo "[xmrig] wake-lock acquired"
fi

if tmux has-session -t "${SESSION}" 2>/dev/null; then
  echo "[xmrig] session '${SESSION}' already exists — attach with: tmux attach -t ${SESSION}"
  exit 0
fi

run_miner() {
  local worker="$1"
  local port="$2"
  cd "${XMRIG_DIR}"
  ./xmrig \
    -o "${POOL}" \
    -u "${WALLET}" \
    -p "${worker}" \
    --threads="${THREADS}" \
    --cpu-priority=2 \
    --randomx-mode=light \
    --coin=monero \
    --http-port="${port}" \
    --http-enabled
}

echo "[xmrig] starting ${INSTANCES} instances → ${POOL}"
tmux new-session -d -s "${SESSION}" -n miners

for i in $(seq 1 "${INSTANCES}"); do
  worker=$(printf '%s-%02d' "${PREFIX}" "${i}")
  port=$((PORT_BASE + i - 1))
  if [[ "${i}" -eq 1 ]]; then
    tmux send-keys -t "${SESSION}:0" \
      "cd '${XMRIG_DIR}' && ./xmrig -o '${POOL}' -u '${WALLET}' -p '${worker}' --threads=${THREADS} --cpu-priority=2 --randomx-mode=light --coin=monero --http-port=${port} --http-enabled" C-m
  else
    tmux split-window -t "${SESSION}:0" -h \
      "cd '${XMRIG_DIR}' && ./xmrig -o '${POOL}' -u '${WALLET}' -p '${worker}' --threads=${THREADS} --cpu-priority=2 --randomx-mode=light --coin=monero --http-port=${port} --http-enabled"
  fi
done

tmux select-layout -t "${SESSION}:0" tiled 2>/dev/null || true

echo "[xmrig] tmux session '${SESSION}' started"
echo "[xmrig] attach: tmux attach -t ${SESSION}"
echo "[xmrig] detach: Ctrl+b d"
echo "[xmrig] stop:   ./scripts/termux/xmrig-stop.sh"
echo "[xmrig] stats:  ./scripts/termux/xmrig-status.sh"
echo "[xmrig] HTTP:   http://127.0.0.1:${PORT_BASE}–$((PORT_BASE + INSTANCES - 1))"
