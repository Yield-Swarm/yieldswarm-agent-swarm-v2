# =========================================================================
# nexus-runtime.hcl — Solenoid 1 (Nexus Chain) orchestration layer
# -------------------------------------------------------------------------
# Granted to Nexus orchestrator AppRoles (backend + sovereign core).
# Reads treasury manifest, mining roots, multicloud operator creds, and
# backend runtime bundle. Can renew tokens but cannot mutate secrets.
# =========================================================================

path "yieldswarm/data/treasury/manifest" {
  capabilities = ["read"]
}
path "yieldswarm/data/treasury/mining_roots" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/nexus" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/backend" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}

# Multicloud launch (Akash, Azure, Vast.ai) from Nexus orchestrator
path "yieldswarm/data/cloud/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/providers/+" {
  capabilities = ["read"]
}
path "yieldswarm/data/akash/+" {
  capabilities = ["read"]
}
path "yieldswarm/metadata/cloud/*" {
  capabilities = ["read", "list"]
}
path "yieldswarm/metadata/providers/*" {
  capabilities = ["read", "list"]
}

# Agent registry fan-out (521-agent capacity)
path "yieldswarm/data/agents/shards/+" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Deny payment hot wallets on orchestration hosts
path "yieldswarm/data/payments/web3" {
  capabilities = ["deny"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
