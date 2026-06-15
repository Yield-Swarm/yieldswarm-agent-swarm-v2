# ============================================================
# HashiCorp Vault — Production Server Configuration
# YieldSwarm AgentSwarm OS v2.0
#
# Topology  : Single-node Integrated Raft (scale to 3/5 nodes
#             by adding retry_join blocks and unique node_ids)
# Auto-unseal: AWS KMS (swap seal block for Azure Key Vault or
#             GCP CKMS if preferred — see commented alternatives)
# TLS       : Terminate at Vault; never run plaintext in prod
# ============================================================

cluster_name = "yieldswarm-vault"

# ── Storage ─────────────────────────────────────────────────
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node-1"

  # Add one block per peer for HA (minimum 3 nodes recommended)
  # retry_join {
  #   leader_api_addr = "https://vault-node-2.internal:8200"
  # }
  # retry_join {
  #   leader_api_addr = "https://vault-node-3.internal:8200"
  # }

  performance_multiplier = 1
}

# ── Listener ─────────────────────────────────────────────────
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/opt/vault/tls/vault.crt"
  tls_key_file  = "/opt/vault/tls/vault.key"

  # Restrict TLS to 1.2+ and strong cipher suites
  tls_min_version = "tls12"
  tls_cipher_suites = "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"

  # Never expose unauthenticated metrics in production
  telemetry {
    unauthenticated_metrics_access = false
  }
}

# ── Auto-unseal (AWS KMS) ────────────────────────────────────
# Replace with azure_keyvault or gcpckms block if needed.
# For dev/test environments only, comment this out and use
# manual unseal keys stored in a secure offline location.
seal "awskms" {
  region     = "us-east-1"
  kms_key_id = "alias/yieldswarm-vault-unseal"
}

# Alternative — Azure Key Vault auto-unseal:
# seal "azurekeyvault" {
#   tenant_id      = "AZURE_TENANT_ID"
#   client_id      = "AZURE_CLIENT_ID"
#   client_secret  = "AZURE_CLIENT_SECRET"
#   vault_name     = "yieldswarm-vault-unseal"
#   key_name       = "vault-unseal-key"
# }

# ── Cluster addresses ────────────────────────────────────────
api_addr     = "https://vault.yieldswarm.internal:8200"
cluster_addr = "https://vault.yieldswarm.internal:8201"

# ── UI ───────────────────────────────────────────────────────
# Enable for operator convenience; restrict with ACL at the
# network layer (VPN/firewall) — never expose to the internet
ui = true

# ── Telemetry ────────────────────────────────────────────────
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = false
  statsite_address          = ""
  statsd_address            = ""
}

# ── Logging ──────────────────────────────────────────────────
log_level        = "Info"
log_format       = "json"
log_file         = "/opt/vault/logs/vault.log"
log_rotate_bytes = 104857600  # 100 MB per file
log_rotate_max_files = 10

# ── Default lease TTLs ───────────────────────────────────────
# Tokens issued without explicit TTL will use these defaults.
# Keep short to minimize blast radius of leaked tokens.
default_lease_ttl = "1h"
max_lease_ttl     = "168h"  # 7 days maximum renewable window

# ── Disable memory locking warning on restricted kernels ─────
# Set to true only if mlock is definitively unavailable.
disable_mlock = false
