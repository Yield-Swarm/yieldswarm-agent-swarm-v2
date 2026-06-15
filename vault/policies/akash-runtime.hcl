# =========================================================================
# akash-runtime.hcl
# -------------------------------------------------------------------------
# Granted to AppRoles used by Akash deployments at container start via
# Vault Agent or hvac entrypoints. Reads workload secrets only; cloud
# provider credentials are explicitly denied.
# =========================================================================

# --- Canonical runtime bundles (kv v2 mount: yieldswarm) -----------------
path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/llm" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/akash" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/kairo" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/payments" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/odysseus" {
  capabilities = ["read"]
}

# --- Legacy layout (backward compatible with setup/05-seed-secrets.sh) ---
path "yieldswarm/data/akash/runtime" {
  capabilities = ["read"]
}

# Per-shard agent fan-out (read only the shard your deployment owns)
path "yieldswarm/data/agents/shards/+" {
  capabilities = ["read"]
}

# RPC + LLM providers
path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/llm/+" {
  capabilities = ["read"]
}

# Third-party integrations surfaced to on-Akash agents
path "yieldswarm/data/integrations/+" {
  capabilities = ["read"]
}

# --- Envelope encryption for persisted workload secrets -----------------
path "transit/encrypt/agent-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/agent-runtime" {
  capabilities = ["update"]
}

# --- Token hygiene -------------------------------------------------------
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Hard deny on cloud-provider creds — Akash workloads must never see them.
path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/providers/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
