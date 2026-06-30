#!/usr/bin/env bash
# Shared SRBMiner-MULTI helpers for PoWUoI pool workers.
set -euo pipefail

srbminer_resolve_binary() {
  local candidate="${SRBMINER_PATH:-./SRBMiner-MULTI}"
  if [[ -x "${candidate}" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi
  if command -v SRBMiner-MULTI >/dev/null 2>&1; then
    command -v SRBMiner-MULTI
    return 0
  fi
  if [[ -x "./SRBMiner-MULTI.exe" ]]; then
    printf '%s\n' "./SRBMiner-MULTI.exe"
    return 0
  fi
  echo "[srbminer] ERROR: SRBMiner-MULTI not found. Set SRBMINER_PATH or download from https://github.com/doktor83/SRBMiner-Multi/releases" >&2
  return 1
}

srbminer_wallet_worker() {
  local wallet="$1"
  local worker="$2"
  if [[ -z "${worker}" ]]; then
    printf '%s\n' "${wallet}"
  else
    printf '%s.%s\n' "${wallet}" "${worker}"
  fi
}

srbminer_sanitize_worker() {
  local raw="${1:-rig-1}"
  echo "${raw}" | tr ' ' '_' | tr -cd '[:alnum:]_-' | cut -c1-32
}
