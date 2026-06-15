# =============================================================================
# Policy: akash-runtime
# -----------------------------------------------------------------------------
# Granted to workloads running on Akash via AppRole. These are long-lived
# containers that fetch their secrets at startup (via Vault Agent) AND
# re-template them on TTL expiry. Capability set is intentionally minimal:
#
#   * READ on runtime application secrets and RPC endpoints.
#   * ENCRYPT/DECRYPT via transit (so the workload never holds raw KMS keys).
#   * NO list, NO write, NO metadata access (prevents secret enumeration if
#     an attacker pops a worker pod).
# =============================================================================

# --- Runtime app secrets (LLM keys, wallet enc keys, master keys, etc.) ---
path "yieldswarm/data/runtime/app" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/wallet" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/depin" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/social" {
  capabilities = ["read"]
}

# --- RPC endpoints (Solana, TON, TAO, Helix, ZEC, ERC4337 bundler, etc.) ---
path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

# --- Transit (encryption-as-a-service for at-rest data the worker generates) ---
path "transit/encrypt/agentswarm-runtime" {
  capabilities = ["update"]
}

path "transit/decrypt/agentswarm-runtime" {
  capabilities = ["update"]
}

path "transit/rewrap/agentswarm-runtime" {
  capabilities = ["update"]
}

# --- Token hygiene + lease renewal (long-lived workload) ---
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "sys/leases/renew" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
