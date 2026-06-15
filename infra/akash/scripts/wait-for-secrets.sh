#!/usr/bin/env bash
# =============================================================================
# wait-for-secrets.sh
# -----------------------------------------------------------------------------
# Block until Vault Agent has rendered every required template. Supervisord
# uses this as a gate so the main app process never starts with a missing
# or stale env file.
#
# Required env:
#   AGENTSWARM_ENV_FILE   path to the runtime env file rendered by vault-agent
#
# Optional env:
#   AGENTSWARM_WAIT_TIMEOUT_SECS    default 120
#   AGENTSWARM_WAIT_POLL_SECS       default 2
# =============================================================================
set -Eeuo pipefail

: "${AGENTSWARM_ENV_FILE:?AGENTSWARM_ENV_FILE must be set}"
TIMEOUT="${AGENTSWARM_WAIT_TIMEOUT_SECS:-120}"
POLL="${AGENTSWARM_WAIT_POLL_SECS:-2}"

deadline=$(( $(date +%s) + TIMEOUT ))

log() {
  printf '{"ts":"%s","level":"%s","msg":"%s","component":"wait-for-secrets"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2"
}

log INFO "Waiting up to ${TIMEOUT}s for ${AGENTSWARM_ENV_FILE}"

while :; do
  if [[ -s "$AGENTSWARM_ENV_FILE" ]]; then
    # Sanity check: at minimum, AGENTSWARM_MASTER_KEY must be present and
    # not equal to the literal placeholder.
    if grep -qE '^AGENTSWARM_MASTER_KEY=.+$' "$AGENTSWARM_ENV_FILE" \
       && ! grep -qE '^AGENTSWARM_MASTER_KEY=REPLACE_ME$' "$AGENTSWARM_ENV_FILE"; then
      log INFO "Secrets rendered. Releasing app start."
      exit 0
    fi
  fi
  if (( $(date +%s) >= deadline )); then
    log ERROR "Timed out waiting for ${AGENTSWARM_ENV_FILE}"
    exit 2
  fi
  sleep "$POLL"
done
