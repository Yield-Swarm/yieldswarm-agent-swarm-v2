#!/usr/bin/env bash
# 10-init-unseal.sh
# Idempotently initialises a Vault cluster and unseals it.
#
# PRODUCTION NOTE: this script writes recovery keys to ${VAULT_INIT_OUT:-/tmp/vault-init.json}
# ONLY when the cluster is NOT auto-unsealing (Shamir mode).  In production
# you should be using transit / cloud KMS auto-unseal (see config/vault-server.hcl)
# and this script will simply exit after `vault operator init -recovery-shares=...`
# without ever materialising secret key shares to disk.

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"

require_bin vault jq
require_env VAULT_ADDR

mode="${VAULT_INIT_MODE:-auto}"            # auto | shamir
out="${VAULT_INIT_OUT:-/run/secrets/vault-init.json}"   # tmpfs by default
shares="${VAULT_INIT_SHARES:-5}"
threshold="${VAULT_INIT_THRESHOLD:-3}"

status_json="$(vault status -format=json || true)"
initialized="$(jq -r .initialized <<<"$status_json")"

if [[ "$initialized" == "true" ]]; then
  log "vault already initialized"
else
  log "initialising vault (mode=$mode shares=$shares threshold=$threshold)"
  install -d -m 0700 "$(dirname "$out")"
  if [[ "$mode" == "shamir" ]]; then
    vault operator init \
      -key-shares="$shares" \
      -key-threshold="$threshold" \
      -format=json > "$out"
    chmod 0400 "$out"
    log "Shamir key shares written to $out -- MOVE TO TEE/HSM AND SHRED IMMEDIATELY"
  else
    vault operator init \
      -recovery-shares="$shares" \
      -recovery-threshold="$threshold" \
      -format=json > "$out"
    chmod 0400 "$out"
    log "recovery keys written to $out -- distribute to break-glass holders, then shred local copy"
  fi
fi

# Unseal loop (no-op when auto-unseal is configured).
sealed="$(vault status -format=json | jq -r .sealed)"
if [[ "$sealed" == "true" ]]; then
  if [[ "$mode" == "shamir" && -f "$out" ]]; then
    log "unsealing with Shamir keys from $out"
    jq -r '.unseal_keys_b64[]' "$out" | head -n "$threshold" | while read -r k; do
      vault operator unseal "$k" >/dev/null
    done
  else
    die "vault is sealed and no Shamir keys available -- check auto-unseal config"
  fi
fi

log "vault initialized=$(vault status -format=json | jq -r .initialized) sealed=$(vault status -format=json | jq -r .sealed)"
