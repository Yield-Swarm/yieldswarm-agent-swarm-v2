# =========================================================================
# nexus-runtime.hcl — Solenoid 1 Nexus Chain orchestration
# -------------------------------------------------------------------------
# Granted to the Nexus coordinator service (Azure control plane + API).
# Reads orchestration secrets, cloud provider credentials, and core keys.
# =========================================================================

path "yieldswarm/data/runtime/nexus" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}

path "yieldswarm/data/providers/azure" {
  capabilities = ["read"]
}

path "yieldswarm/data/providers/akash" {
  capabilities = ["read"]
}

path "yieldswarm/data/providers/vastai" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "transit/encrypt/nexus-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/nexus-runtime" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
