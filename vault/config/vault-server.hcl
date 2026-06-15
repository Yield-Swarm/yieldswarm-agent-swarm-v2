# =============================================================================
# HashiCorp Vault Server Configuration — Production
# YieldSwarm AgentSwarm OS v2.0
#
# Run with: vault server -config=/vault/config/vault-server.hcl
#
# Runtime environment variables required for Azure auto-unseal:
#   AZURE_TENANT_ID             — Azure AD tenant
#   AZURE_CLIENT_ID             — Service principal (or leave blank for MSI)
#   AZURE_CLIENT_SECRET         — SP secret (or leave blank for MSI)
#   VAULT_AZUREKEYVAULT_VAULT_NAME  — Azure Key Vault name
#   VAULT_AZUREKEYVAULT_KEY_NAME    — RSA key name inside Key Vault
# =============================================================================

ui            = true
disable_mlock = false
log_level     = "info"
log_format    = "json"

# -----------------------------------------------------------------------------
# Storage: Integrated Raft (HA, no external dependency)
# -----------------------------------------------------------------------------
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-node-0"

  # Additional peers join by pointing to the first node; add retry_join
  # blocks for each peer once the cluster grows beyond one node.
  # retry_join {
  #   leader_api_addr         = "https://vault-1.vault-internal:8200"
  #   leader_ca_cert_file     = "/vault/tls/ca.crt"
  #   leader_client_cert_file = "/vault/tls/vault.crt"
  #   leader_client_key_file  = "/vault/tls/vault.key"
  # }
}

# -----------------------------------------------------------------------------
# Listener: HTTPS only, TLS 1.3 minimum
# -----------------------------------------------------------------------------
listener "tcp" {
  address            = "0.0.0.0:8200"
  cluster_address    = "0.0.0.0:8201"
  tls_cert_file      = "/vault/tls/vault.crt"
  tls_key_file       = "/vault/tls/vault.key"
  tls_client_ca_file = "/vault/tls/ca.crt"
  tls_min_version    = "tls13"
  tls_disable        = false

  # Restrict access from Akash/RunPod egress CIDRs as needed.
  # x_forwarded_for_authorized_addrs = "10.0.0.0/8"
}

# -----------------------------------------------------------------------------
# Auto-unseal: Azure Key Vault RSA key
# All connection parameters are injected via environment variables (see top).
# -----------------------------------------------------------------------------
seal "azurekeyvault" {
  # Parameters are read automatically from the environment variables listed
  # at the top of this file. No secrets are stored in this file.
}

# Cluster peer advertisement addresses
api_addr     = "https://vault.yieldswarm.internal:8200"
cluster_addr = "https://vault.yieldswarm.internal:8201"

# -----------------------------------------------------------------------------
# Audit: file-based JSON audit log (always enable in production)
# -----------------------------------------------------------------------------
# audit {
#   type = "file"
#   options = {
#     file_path = "/vault/logs/audit.log"
#     mode      = "0600"
#   }
# }
# Enable after init: vault audit enable file file_path=/vault/logs/audit.log

# -----------------------------------------------------------------------------
# Telemetry: Prometheus scraping
# -----------------------------------------------------------------------------
telemetry {
  prometheus_retention_time          = "30s"
  disable_hostname                   = true
  unauthenticated_metrics_access     = false
}
