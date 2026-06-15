terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.24.0"
    }
  }
}

provider "vault" {
  address          = var.vault_addr
  namespace        = var.vault_namespace
  skip_child_token = true
}
