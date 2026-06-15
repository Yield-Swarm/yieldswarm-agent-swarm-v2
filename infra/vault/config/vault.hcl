# =============================================================================
# YieldSwarm — HashiCorp Vault server configuration (production-grade)
# =============================================================================
# Integrated Storage (Raft) — no external storage dependency, supports HA.
# Deploy this file to /etc/vault.d/vault.hcl on each Vault node.
#
# Render the placeholders (NODE_NAME, NODE_FQDN, CLUSTER_PEERS) per-node via
# your config-management tooling. NEVER bake unseal keys or tokens into this
# file — Vault is unsealed and authenticated out of band.
# =============================================================================

ui = true

# ---------------------------------------------------------------------------
# Storage — Integrated Storage (Raft). Survives reboots, replicates across HA.
# ---------------------------------------------------------------------------
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "NODE_NAME"

  # One retry_join block per peer. Vault auto-discovers the active leader.
  retry_join {
    leader_api_addr         = "https://vault-0.NODE_FQDN:8200"
    leader_ca_cert_file     = "/etc/vault.d/tls/ca.pem"
    leader_client_cert_file = "/etc/vault.d/tls/vault.pem"
    leader_client_key_file  = "/etc/vault.d/tls/vault-key.pem"
  }
  retry_join {
    leader_api_addr         = "https://vault-1.NODE_FQDN:8200"
    leader_ca_cert_file     = "/etc/vault.d/tls/ca.pem"
    leader_client_cert_file = "/etc/vault.d/tls/vault.pem"
    leader_client_key_file  = "/etc/vault.d/tls/vault-key.pem"
  }
  retry_join {
    leader_api_addr         = "https://vault-2.NODE_FQDN:8200"
    leader_ca_cert_file     = "/etc/vault.d/tls/ca.pem"
    leader_client_cert_file = "/etc/vault.d/tls/vault.pem"
    leader_client_key_file  = "/etc/vault.d/tls/vault-key.pem"
  }
}

# ---------------------------------------------------------------------------
# Listener — TLS only. Plaintext (tls_disable) is forbidden in production.
# ---------------------------------------------------------------------------
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = false
  tls_cert_file = "/etc/vault.d/tls/vault.pem"
  tls_key_file  = "/etc/vault.d/tls/vault-key.pem"

  # Force TLS 1.2+ and disable HTTP/2 plaintext upgrades.
  tls_min_version = "tls12"

  # Telemetry endpoint hardening.
  telemetry {
    unauthenticated_metrics_access = false
  }
}

# ---------------------------------------------------------------------------
# Cluster / API addresses — must be reachable by peers and clients.
# ---------------------------------------------------------------------------
api_addr     = "https://NODE_FQDN:8200"
cluster_addr = "https://NODE_FQDN:8201"

# ---------------------------------------------------------------------------
# Auto-unseal (recommended). Avoids manual Shamir unseal on every restart.
# Pick ONE backend. Example below uses Azure Key Vault to match the Azure
# integration; comment it out and use Shamir keys if no KMS is available.
# ---------------------------------------------------------------------------
# seal "azurekeyvault" {
#   tenant_id      = "AZURE_TENANT_ID"
#   vault_name     = "yieldswarm-unseal-kv"
#   key_name       = "vault-unseal"
#   # client_id / client_secret supplied via env: VAULT_AZUREKEYVAULT_CLIENT_ID,
#   # VAULT_AZUREKEYVAULT_CLIENT_SECRET (or managed identity).
# }

# ---------------------------------------------------------------------------
# Operational hardening.
# ---------------------------------------------------------------------------
disable_mlock      = false   # keep memory from swapping secrets to disk
log_level          = "info"
log_format         = "json"
default_lease_ttl  = "768h"  # 32 days
max_lease_ttl      = "8760h" # 365 days

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
