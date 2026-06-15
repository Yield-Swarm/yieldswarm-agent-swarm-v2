## YieldSwarm Vault server config (HA, Raft, TLS)
## Place at /etc/vault.d/vault.hcl on each node.

ui            = true
cluster_name  = "yieldswarm-vault"
disable_mlock = false

# Persistent integrated storage (Raft).  3 or 5 node cluster recommended.
storage "raft" {
  path    = "/var/lib/vault/raft"
  node_id = "{{ env \"VAULT_NODE_ID\" }}"

  retry_join {
    leader_api_addr         = "https://vault-0.vault.internal:8200"
    leader_ca_cert_file     = "/etc/vault.d/tls/ca.crt"
    leader_client_cert_file = "/etc/vault.d/tls/client.crt"
    leader_client_key_file  = "/etc/vault.d/tls/client.key"
  }
  retry_join {
    leader_api_addr         = "https://vault-1.vault.internal:8200"
    leader_ca_cert_file     = "/etc/vault.d/tls/ca.crt"
    leader_client_cert_file = "/etc/vault.d/tls/client.crt"
    leader_client_key_file  = "/etc/vault.d/tls/client.key"
  }
  retry_join {
    leader_api_addr         = "https://vault-2.vault.internal:8200"
    leader_ca_cert_file     = "/etc/vault.d/tls/ca.crt"
    leader_client_cert_file = "/etc/vault.d/tls/client.crt"
    leader_client_key_file  = "/etc/vault.d/tls/client.key"
  }
}

listener "tcp" {
  address                            = "0.0.0.0:8200"
  cluster_address                    = "0.0.0.0:8201"
  tls_cert_file                      = "/etc/vault.d/tls/vault.crt"
  tls_key_file                       = "/etc/vault.d/tls/vault.key"
  tls_client_ca_file                 = "/etc/vault.d/tls/ca.crt"
  tls_min_version                    = "tls13"
  tls_require_and_verify_client_cert = false
  tls_disable_client_certs           = false
  x_forwarded_for_authorized_addrs   = "10.0.0.0/8"
}

api_addr     = "https://{{ env \"VAULT_NODE_FQDN\" }}:8200"
cluster_addr = "https://{{ env \"VAULT_NODE_FQDN\" }}:8201"

# Auto-unseal with cloud KMS (pick one; uncomment what fits).
# seal "awskms"   { region = "us-west-2"  kms_key_id = "alias/yieldswarm-vault" }
# seal "azurekeyvault" {
#   tenant_id      = "{{ env \"AZURE_TENANT_ID\" }}"
#   vault_name     = "yieldswarm-unseal"
#   key_name       = "vault-unseal"
# }
seal "transit" {
  address         = "{{ env \"VAULT_TRANSIT_ADDR\" }}"
  token           = "{{ env \"VAULT_TRANSIT_TOKEN\" }}"
  disable_renewal = "false"
  key_name        = "autounseal"
  mount_path      = "transit/"
  tls_skip_verify = "false"
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}

log_level         = "info"
log_format        = "json"
default_lease_ttl = "24h"
max_lease_ttl     = "720h"
