# Production Vault server configuration template.
# Mount TLS certs at /vault/tls and unseal keys via your KMS auto-unseal backend.

ui = true

storage "raft" {
  path    = "/vault/data"
  node_id = "yieldswarm-vault-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_cert_file   = "/vault/tls/vault.crt"
  tls_key_file    = "/vault/tls/vault.key"
  tls_min_version = "tls12"
}

api_addr     = "https://vault.yieldswarm.internal:8200"
cluster_addr = "https://vault.yieldswarm.internal:8201"

# Replace with your KMS auto-unseal block in production (AWS/GCP/Azure).
# seal "awskms" { ... }

disable_mlock = true

default_lease_ttl  = "1h"
max_lease_ttl      = "24h"
log_level          = "info"
