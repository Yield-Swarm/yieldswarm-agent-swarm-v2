terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.5.0"
    }
  }
}

provider "vault" {
  # Configure with VAULT_ADDR, VAULT_TOKEN, VAULT_NAMESPACE, and TLS env vars.
}
