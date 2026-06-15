# HashiCorp Vault Server Configuration
# YieldSwarm AgentSwarm OS — Production Grade
#
# Integrated Raft storage — no external coordinator.
# Swap for Consul backend in multi-datacenter deployments.

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-node-1"

  # For HA — add additional nodes here.
  # retry_join {
  #   leader_api_addr         = "https://vault-node-2:8200"
  #   leader_ca_cert_file     = "/vault/tls/ca.crt"
  #   leader_client_cert_file = "/vault/tls/vault.crt"
  #   leader_client_key_file  = "/vault/tls/vault.key"
  # }
}

# TLS-secured API listener
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/vault.crt"
  tls_key_file  = "/vault/tls/vault.key"

  # Optional: restrict to mutual TLS for Terraform/CI clients
  # tls_require_and_verify_client_cert = true
  # tls_client_ca_file = "/vault/tls/ca.crt"

  # Expose unauthenticated /v1/sys/metrics for Prometheus scraping
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# Intra-cluster listener (Raft peer communication)
listener "tcp" {
  address     = "0.0.0.0:8201"
  tls_cert_file = "/vault/tls/vault.crt"
  tls_key_file  = "/vault/tls/vault.key"
  cluster_address = "0.0.0.0:8201"
}

# Public addresses — replace VAULT_HOSTNAME with your FQDN or IP
api_addr     = "https://VAULT_HOSTNAME:8200"
cluster_addr = "https://VAULT_HOSTNAME:8201"

# Enable Web UI
ui = true

# Global lease limits
default_lease_ttl = "12h"
max_lease_ttl     = "768h"   # 32 days

# Log level: trace | debug | info | warn | error
log_level = "info"
log_format = "json"

# Prometheus telemetry
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}

# ---------------------------------------------------------------------------
# Auto-Unseal via Azure Key Vault (recommended for production on Azure).
# Comment out if using manual unseal keys or a different KMS provider.
# ---------------------------------------------------------------------------
# seal "azurekeyvault" {
#   tenant_id      = "AZURE_TENANT_ID"
#   client_id      = "AZURE_CLIENT_ID"
#   client_secret  = "AZURE_CLIENT_SECRET"
#   vault_name     = "ys-vault-unseal"
#   key_name       = "vault-unseal-key"
# }

# ---------------------------------------------------------------------------
# Alternative: AWS KMS auto-unseal
# ---------------------------------------------------------------------------
# seal "awskms" {
#   region     = "us-east-1"
#   kms_key_id = "alias/vault-unseal-key"
# }
