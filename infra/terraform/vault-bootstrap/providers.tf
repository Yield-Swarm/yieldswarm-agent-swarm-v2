provider "vault" {
  address         = var.vault_address
  namespace       = var.vault_namespace
  ca_cert_file    = var.vault_ca_cert_file
  skip_tls_verify = var.vault_skip_tls_verify
  token           = var.vault_token
}
