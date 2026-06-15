# =========================================================================
# kairo-runtime.hcl
# -------------------------------------------------------------------------
# Granted to Kairo driver API and frontend deployments. Reads driver
# identity encryption keys, Mapbox token, and payment rail credentials.
# =========================================================================

path "yieldswarm/data/kairo/runtime" {
  capabilities = ["read"]
}

path "yieldswarm/data/kairo/drivers/+" {
  capabilities = ["read", "create", "update"]
}

path "yieldswarm/data/payments/+" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "transit/encrypt/kairo-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/kairo-runtime" {
  capabilities = ["update"]
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
