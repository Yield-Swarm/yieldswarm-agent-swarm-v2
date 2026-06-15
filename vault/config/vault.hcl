# Production Vault server configuration template.
# Copy to /etc/vault.d/vault.hcl on your Vault host and adjust addresses/certs.

ui            = true
cluster_addr  = "https://vault.yieldswarm.internal:8201"
api_addr      = "https://vault.yieldswarm.internal:8200"

storage "raft" {
  path    = "/var/lib/vault/data"
  node_id = "vault-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/vault.d/tls/vault.key"
  tls_min_version = "tls12"
}

# Enable audit logging (required for production)
# audit_device "file" {
#   file_path = "/var/log/vault/audit.log"
#   log_raw   = false
# }

# Seal configuration — use auto-unseal in production (AWS KMS, Azure Key Vault, etc.)
# seal "awskms" {
#   region     = "us-east-1"
#   kms_key_id = "alias/vault-unseal"
# }

disable_mlock = false
