terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0.0"
    }
  }
}

provider "vault" {
  address         = var.vault_addr
  namespace       = var.vault_namespace == "" ? null : var.vault_namespace
  skip_tls_verify = var.vault_skip_tls_verify
}
