provider "vault" {
  address               = var.vault_addr
  namespace             = var.vault_namespace
  ca_cert_file          = var.vault_ca_cert_file
  skip_tls_verify       = var.vault_skip_tls_verify
  max_lease_ttl_seconds = 1200
  skip_child_token      = true
}
