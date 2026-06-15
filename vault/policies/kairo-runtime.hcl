# Kairo driver runtime — read own driver key material, write telemetry attestations.
path "yieldswarm/data/kairo/drivers/*" {
  capabilities = ["create", "read", "update"]
}

path "yieldswarm/data/kairo/telemetry/*" {
  capabilities = ["create", "read"]
}

path "yieldswarm/metadata/kairo/*" {
  capabilities = ["list", "read"]
}
