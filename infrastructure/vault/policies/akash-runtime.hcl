# =============================================================================
# Policy: akash-runtime
# Purpose: Runtime read access for OpenClaw / AgentSwarm containers running on
#          Akash. The container exchanges its AppRole role_id + (wrapped)
#          secret_id for a short-lived Vault token, then reads its runtime
#          secrets and exports them as env vars before exec'ing the workload.
# Mount  : kv/ (KV v2)
# =============================================================================

# --- Runtime application secrets ---------------------------------------------
path "kv/data/yieldswarm/runtime/openclaw" {
  capabilities = ["read"]
}

path "kv/data/yieldswarm/runtime/agentswarm" {
  capabilities = ["read"]
}

# RPC endpoints are needed at runtime by the trading / consensus agents.
path "kv/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

# Akash CLI / wallet bootstrap (chain id, node, keyring backend, mnemonic).
path "kv/data/yieldswarm/runtime/akash" {
  capabilities = ["read"]
}

# --- Transit encrypt/decrypt for wallet payloads -----------------------------
# Containers must NEVER export raw private keys; they call transit to
# encrypt/decrypt at use-time.
path "transit/encrypt/yieldswarm-wallets" {
  capabilities = ["update"]
}

path "transit/decrypt/yieldswarm-wallets" {
  capabilities = ["update"]
}

# --- Token self-management (periodic token renewal) --------------------------
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# --- Hard deny on sys/ and any other path ------------------------------------
path "sys/*" {
  capabilities = ["deny"]
}

path "auth/approle/*" {
  capabilities = ["deny"]
}
