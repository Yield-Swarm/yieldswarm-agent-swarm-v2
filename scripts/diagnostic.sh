#!/usr/bin/env bash
# System diagnostic — run in Codespace before deploying Bittensor workers.
# Paste the line under === ACTIVE SYSTEM STATE === back to the team.

set -euo pipefail

export PATH="/workspace/bin:${PATH}"

line() { printf '%s\n' "$*"; }

# Collect state
PS_OK=false; command -v provider-services >/dev/null && PS_OK=true
VAULT_OK=false; [[ -n "${VAULT_ADDR:-}" ]] && vault status >/dev/null 2>&1 && VAULT_OK=true
KAIRO_OK=false; curl -sf http://127.0.0.1:8090/health >/dev/null 2>&1 && KAIRO_OK=true
OLLAMA_OK=false; curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && OLLAMA_OK=true
GPU_OK=false; command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1 && GPU_OK=true
BT_OK=false; python3 -c "import bittensor" >/dev/null 2>&1 && BT_OK=true

STATE="vault=${VAULT_OK} provider-services=${PS_OK} kairo=${KAIRO_OK} ollama=${OLLAMA_OK} gpu=${GPU_OK} bittensor=${BT_OK} netuid=${BT_NETUID:-unset} network=${BT_NETWORK:-unset}"

line ""
line "=== ACTIVE SYSTEM STATE ==="
line "${STATE}"
line "==========================="
line ""
line "Components:"
line "  Vault:              ${VAULT_ADDR:-not set}"
line "  provider-services:  $(command -v provider-services 2>/dev/null || echo missing)"
line "  Kairo bridge :8090: ${KAIRO_OK}"
line "  Ollama       :11434: ${OLLAMA_OK}"
line "  GPU (nvidia-smi):   ${GPU_OK}"
line "  Bittensor python:   ${BT_OK}"
line "  BT_NETUID:          ${BT_NETUID:-unset}"
line "  BT_NETWORK:         ${BT_NETWORK:-finney}"
