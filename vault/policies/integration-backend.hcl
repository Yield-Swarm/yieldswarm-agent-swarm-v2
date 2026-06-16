# =========================================================================
# integration-backend.hcl — YieldSwarm integration API on Akash (:8080)
# Arena telemetry, sovereign state, Akash Console + Solana reads.
# =========================================================================

path "yieldswarm/data/runtime/akash" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/backend" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/odysseus" {
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

path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
