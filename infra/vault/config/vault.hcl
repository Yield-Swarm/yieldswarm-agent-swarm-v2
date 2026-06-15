# ---------------------------------------------------------------------------
# Production Vault server config for the YieldSwarm / APN platform.
#
# - Integrated Raft storage (no external dependency, durable).
# - TLS required (terminate at the Vault listener, not a load balancer).
# - mlock enabled (paged secrets stay off swap).
# - UI enabled for break-glass operators only; lock down at the network layer.
# - Telemetry exported in Prometheus format for the platform monitoring stack
#   (MONITORING_PROMETHEUS_URL in .env.example).
#
# Run with:
#   vault server -config=/etc/vault.d/vault.hcl
# ---------------------------------------------------------------------------

ui            = true
disable_mlock = false
cluster_name  = "apn-vault"

# Persistent, replicated storage. Raft requires `node_id` to be unique
# per node; set it via the VAULT_RAFT_NODE_ID env var on each instance.
storage "raft" {
  path    = "/var/lib/vault/raft"
  node_id = "node-1"

  # Auto-join across the Vault cluster using cloud discovery. Configure
  # the discovery string per environment (Azure VMSS tag, DO tag, etc.).
  retry_join {
    auto_join        = "provider=azurerm tag_name=role tag_value=apn-vault"
    auto_join_scheme = "https"
  }
}

# TLS-only listener. Certificates are issued by the platform PKI and
# rotated by cert-manager / step-ca. Never expose port 8200 without TLS.
listener "tcp" {
  address                            = "0.0.0.0:8200"
  cluster_address                    = "0.0.0.0:8201"
  tls_cert_file                      = "/etc/vault.d/tls/server.crt"
  tls_key_file                       = "/etc/vault.d/tls/server.key"
  tls_client_ca_file                 = "/etc/vault.d/tls/ca.crt"
  tls_min_version                    = "tls13"
  tls_require_and_verify_client_cert = false
  x_forwarded_for_authorized_addrs   = "10.0.0.0/8"
}

# Auto-unseal via cloud KMS. Pick the block that matches the environment
# and remove the others. Never ship a Shamir-only production cluster.
seal "azurekeyvault" {
  tenant_id      = ""    # set via VAULT_AZUREKEYVAULT_TENANT_ID
  client_id      = ""    # set via VAULT_AZUREKEYVAULT_CLIENT_ID
  client_secret  = ""    # set via VAULT_AZUREKEYVAULT_CLIENT_SECRET
  vault_name     = ""    # set via VAULT_AZUREKEYVAULT_VAULT_NAME
  key_name       = "apn-vault-unseal"
}

# Cluster + API addresses used by Raft peers and clients behind a load
# balancer. Override with VAULT_API_ADDR / VAULT_CLUSTER_ADDR per node.
api_addr     = "https://vault.apn.internal:8200"
cluster_addr = "https://vault.apn.internal:8201"

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}

# Force authenticated callers to renew often; short TTLs blunt token theft.
default_lease_ttl = "1h"
max_lease_ttl     = "24h"
