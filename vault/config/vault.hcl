# YieldSwarm production Vault server configuration.
# Deploy behind TLS termination (load balancer or reverse proxy).
# For HA: use integrated storage (Raft) with 3+ nodes.

ui            = true
cluster_addr  = "https://vault.yieldswarm.internal:8201"
api_addr      = "https://vault.yieldswarm.internal:8200"

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/vault.crt"
  tls_key_file  = "/vault/tls/vault.key"
  tls_min_version = "tls12"
}

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"

  retry_join {
    leader_api_addr = "https://vault-1.yieldswarm.internal:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-2.yieldswarm.internal:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-3.yieldswarm.internal:8200"
  }
}

# Dev-only single-node file backend (uncomment for local bootstrap; never in prod)
# storage "file" {
#   path = "/vault/data"
# }

# Auto-unseal via Transit (recommended for production).
# Use a dedicated unseal Vault cluster — do NOT point transit at this same cluster.
# Uncomment after the unseal Vault is operational:
#
# seal "transit" {
#   address         = "https://vault-unseal.yieldswarm.internal:8200"
#   disable_renewal = "false"
#   key_name        = "autounseal"
#   mount_path      = "transit/"
# }

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}

default_lease_ttl = "1h"
max_lease_ttl     = "24h"

# Audit logging — required for production compliance
# Enable after bootstrap via: vault audit enable file file_path=/vault/audit/audit.log
