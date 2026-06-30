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

pearl_validate_wallet() {
  local wallet="$1"
  if [[ "${wallet}" =~ ^prl1[a-z0-9]{20,}$ ]]; then
    return 0
  fi
  echo "[pearl] ERROR: wallet must be a Pearl bech32m address starting with prl1 (not Solana/ETH)." >&2
  echo "[pearl]        Create one: Pearl Desktop Wallet or https://prl.2miners.com/help" >&2
  echo "[pearl]        Got: ${wallet:0:8}… (${#wallet} chars)" >&2
  return 1
}

pearl_validate_pool() {
  local pool="$1"
  if [[ "${pool}" == *"etc.2miners"* || "${pool}" == *":1010"* ]]; then
    echo "[pearl] ERROR: ${pool} is Ethereum Classic — use prl.2miners.com:1818 for PearlHash" >&2
    return 1
  fi
  if [[ "${pool}" != *"prl"* && "${pool}" != *"pearl"* && "${pool}" != *"alphapool"* && "${pool}" != *"suprnova"* ]]; then
    echo "[pearl] WARN: pool '${pool}' may not be a Pearl endpoint — expected prl.2miners.com:1818 or similar" >&2
  fi
  return 0
}
