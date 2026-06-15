# Reference Vault server configuration for production deployment.
# Mount this file when starting Vault (dev uses vault server -dev).
#
# Production: use HA storage backend (Raft or Consul) and TLS termination.

ui            = true
cluster_addr  = "https://vault.yieldswarm.internal:8201"
api_addr      = "https://vault.yieldswarm.internal:8200"
disable_mlock = false

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault/tls/vault.crt"
  tls_key_file  = "/etc/vault/tls/vault.key"
}

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-1"
}

# Uncomment and configure for HA Raft cluster members.
# storage "raft" {
#   retry_join {
#     leader_api_addr = "https://vault-1.yieldswarm.internal:8200"
#   }
# }

seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/yieldswarm-vault-unseal"
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}
