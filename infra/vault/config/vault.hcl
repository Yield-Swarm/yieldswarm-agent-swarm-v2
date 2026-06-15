# =============================================================================
# YieldSwarm Production Vault Server Configuration
# -----------------------------------------------------------------------------
# This is the canonical configuration used to run a HashiCorp Vault server in
# production for the AgentSwarm OS. It assumes:
#
#   * Vault >= 1.15
#   * Raft integrated storage (no external Consul required)
#   * TLS terminated by Vault itself (NOT by an upstream LB) so unseal traffic
#     and AppRole logins stay E2E encrypted.
#   * Auto-unseal via Azure Key Vault (other seal stanzas live next to this
#     file as `seal-*.hcl` and can be sym-linked when running on different
#     clouds; see SECRETS.md).
#
# All paths are absolute and assume the official `hashicorp/vault` image
# layout (/vault/{config,data,logs,tls}). Adjust only via environment-specific
# overlay files, never by editing this file in-place.
# =============================================================================

ui            = true
cluster_name  = "yieldswarm-vault"
disable_mlock = false
log_level     = "info"
log_format    = "json"

# -----------------------------------------------------------------------------
# Listener: TLS-only, mTLS optional (enable tls_require_and_verify_client_cert
# once every client has been issued a Vault-CA-signed cert via PKI engine).
# -----------------------------------------------------------------------------
listener "tcp" {
  address                            = "0.0.0.0:8200"
  cluster_address                    = "0.0.0.0:8201"
  tls_cert_file                      = "/vault/tls/vault.crt"
  tls_key_file                       = "/vault/tls/vault.key"
  tls_client_ca_file                 = "/vault/tls/ca.crt"
  tls_min_version                    = "tls13"
  tls_disable_client_certs           = false
  tls_require_and_verify_client_cert = false
  x_forwarded_for_authorized_addrs   = "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  telemetry {
    unauthenticated_metrics_access = false
  }
}

# -----------------------------------------------------------------------------
# Storage: Raft integrated storage. Three-node cluster minimum for production.
# `retry_join` blocks are populated by Terraform at bring-up time.
# -----------------------------------------------------------------------------
storage "raft" {
  path    = "/vault/data"
  node_id = "VAULT_NODE_ID"

  retry_join {
    leader_api_addr         = "https://vault-0.vault.internal:8200"
    leader_ca_cert_file     = "/vault/tls/ca.crt"
    leader_client_cert_file = "/vault/tls/vault.crt"
    leader_client_key_file  = "/vault/tls/vault.key"
  }
  retry_join {
    leader_api_addr         = "https://vault-1.vault.internal:8200"
    leader_ca_cert_file     = "/vault/tls/ca.crt"
    leader_client_cert_file = "/vault/tls/vault.crt"
    leader_client_key_file  = "/vault/tls/vault.key"
  }
  retry_join {
    leader_api_addr         = "https://vault-2.vault.internal:8200"
    leader_ca_cert_file     = "/vault/tls/ca.crt"
    leader_client_cert_file = "/vault/tls/vault.crt"
    leader_client_key_file  = "/vault/tls/vault.key"
  }

  performance_multiplier = 1

  # `autopilot_redundancy_zone` is a Vault Enterprise feature. Uncomment
  # below if you are running Vault Enterprise; OSS users should leave it
  # commented to avoid a warning at start.
  # autopilot_redundancy_zone = "default"
}

# -----------------------------------------------------------------------------
# Auto-unseal. Default = Azure Key Vault. Swap this stanza out for an
# `awskms`, `gcpckms`, or `transit` block on other clouds (see SECRETS.md).
# -----------------------------------------------------------------------------
seal "azurekeyvault" {
  tenant_id      = "AZURE_TENANT_ID"
  client_id      = "AZURE_CLIENT_ID"
  client_secret  = "AZURE_CLIENT_SECRET"
  vault_name     = "yieldswarm-unseal-kv"
  key_name       = "vault-unseal-key"
}

# -----------------------------------------------------------------------------
# Cluster + API addresses (override via env: VAULT_API_ADDR / VAULT_CLUSTER_ADDR)
# -----------------------------------------------------------------------------
api_addr     = "https://vault.yieldswarm.internal:8200"
cluster_addr = "https://VAULT_NODE_FQDN:8201"

# -----------------------------------------------------------------------------
# Telemetry (Prometheus scrape on /v1/sys/metrics?format=prometheus)
# -----------------------------------------------------------------------------
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}

# -----------------------------------------------------------------------------
# Service registration (optional, Consul-aware deployments only)
# -----------------------------------------------------------------------------
# service_registration "kubernetes" {}

# -----------------------------------------------------------------------------
# Plugin directory (for future custom secrets engines)
# -----------------------------------------------------------------------------
plugin_directory = "/vault/plugins"
