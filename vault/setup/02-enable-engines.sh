#!/usr/bin/env bash
# =============================================================================
# 02-enable-engines.sh — Enable secrets engines and audit devices
# YieldSwarm AgentSwarm OS v2.0
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN (root token) exported
#   - Vault initialized and unsealed
# =============================================================================
set -euo pipefail

enable_engine_if_missing() {
  local path="$1"
  local type="$2"
  local description="$3"
  shift 3
  if vault secrets list -format=json | python3 -c "import sys,json; mounts=json.load(sys.stdin); exit(0 if '${path}/' in mounts else 1)" 2>/dev/null; then
    echo "[02] Engine already enabled: ${path}/"
  else
    vault secrets enable -path="${path}" -description="${description}" "$@" "${type}"
    echo "[02] Enabled: ${path}/ (${type})"
  fi
}

enable_auth_if_missing() {
  local path="$1"
  local type="$2"
  if vault auth list -format=json | python3 -c "import sys,json; mounts=json.load(sys.stdin); exit(0 if '${path}/' in mounts else 1)" 2>/dev/null; then
    echo "[02] Auth method already enabled: ${path}/"
  else
    vault auth enable -path="${path}" "${type}"
    echo "[02] Enabled auth: ${path}/ (${type})"
  fi
}

echo "[02] === Enabling secrets engines ==="

# KV v2 — primary secret store for all application secrets
enable_engine_if_missing "secret" "kv" "YieldSwarm KV v2 secrets" \
  -version=2

# Transit — encryption-as-a-service (wallet key encryption, TEE payloads)
enable_engine_if_missing "transit" "transit" "YieldSwarm transit encryption"

# PKI — internal TLS certificate issuance (Vault ↔ agents mTLS)
enable_engine_if_missing "pki" "pki" "YieldSwarm internal PKI" \
  -max-lease-ttl=87600h

echo ""
echo "[02] === Tuning KV v2 engine ==="
vault secrets tune -default-lease-ttl=768h -max-lease-ttl=8760h secret/
echo "[02] KV v2 lease TTL: default 32d, max 365d"

echo ""
echo "[02] === Enabling auth methods ==="
enable_auth_if_missing "approle" "approle"

echo ""
echo "[02] === Enabling audit device ==="
mkdir -p /vault/logs
if vault audit list -format=json | python3 -c "import sys,json; devices=json.load(sys.stdin); exit(0 if 'file/' in devices else 1)" 2>/dev/null; then
  echo "[02] Audit device already enabled."
else
  vault audit enable file file_path=/vault/logs/audit.log mode=0600
  echo "[02] Audit log enabled at /vault/logs/audit.log"
fi

echo ""
echo "[02] === PKI root CA setup ==="
# Only configure PKI if no root cert yet
if ! vault read pki/cert/ca -format=json >/dev/null 2>&1; then
  vault write pki/root/generate/internal \
    common_name="YieldSwarm Internal CA" \
    ttl=87600h \
    key_type=rsa \
    key_bits=4096 \
    >/dev/null
  vault write pki/config/urls \
    issuing_certificates="https://vault.yieldswarm.internal:8200/v1/pki/ca" \
    crl_distribution_points="https://vault.yieldswarm.internal:8200/v1/pki/crl"
  echo "[02] PKI root CA generated."
else
  echo "[02] PKI root CA already exists."
fi

echo ""
echo "[02] All engines enabled. Proceed to 03-write-policies.sh"
