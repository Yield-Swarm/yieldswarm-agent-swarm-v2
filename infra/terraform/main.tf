locals {
  vault_namespace = trimspace(var.vault_namespace) == "" ? null : trimspace(var.vault_namespace)
}

provider "vault" {
  address   = var.vault_addr
  token     = var.vault_token
  namespace = local.vault_namespace
}

data "vault_kv_secret_v2" "azure" {
  mount = var.vault_cloud_mount
  name  = var.azure_secret_name
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_cloud_mount
  name  = var.runpod_secret_name
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_cloud_mount
  name  = var.vultr_secret_name
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_cloud_mount
  name  = var.digitalocean_secret_name
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_rpc_mount
  name  = var.rpc_secret_name
}

locals {
  azure_credentials = data.vault_kv_secret_v2.azure.data
  runpod_credentials = data.vault_kv_secret_v2.runpod.data
  vultr_credentials = data.vault_kv_secret_v2.vultr.data
  digitalocean_credentials = data.vault_kv_secret_v2.digitalocean.data
  rpc_credentials = data.vault_kv_secret_v2.rpc.data
}

resource "terraform_data" "validate_secret_schema" {
  input = "vault-secret-schema"

  lifecycle {
    precondition {
      condition = alltrue([
        for key in ["client_id", "client_secret", "subscription_id", "tenant_id"] :
        try(trimspace(local.azure_credentials[key]) != "", false)
      ])
      error_message = "Vault secret cloud/${var.azure_secret_name} must include client_id, client_secret, subscription_id, tenant_id."
    }

    precondition {
      condition     = try(trimspace(local.runpod_credentials["api_key"]) != "", false)
      error_message = "Vault secret cloud/${var.runpod_secret_name} must include api_key."
    }

    precondition {
      condition     = try(trimspace(local.vultr_credentials["api_key"]) != "", false)
      error_message = "Vault secret cloud/${var.vultr_secret_name} must include api_key."
    }

    precondition {
      condition     = try(trimspace(local.digitalocean_credentials["token"]) != "", false)
      error_message = "Vault secret cloud/${var.digitalocean_secret_name} must include token."
    }

    precondition {
      condition     = try(trimspace(local.rpc_credentials["primary_url"]) != "", false)
      error_message = "Vault secret rpc/${var.rpc_secret_name} must include primary_url."
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = local.azure_credentials["client_id"]
  client_secret   = local.azure_credentials["client_secret"]
  subscription_id = local.azure_credentials["subscription_id"]
  tenant_id       = local.azure_credentials["tenant_id"]
}

provider "digitalocean" {
  token = local.digitalocean_credentials["token"]
}

provider "runpod" {
  api_key = local.runpod_credentials["api_key"]
}

provider "vultr" {
  api_key = local.vultr_credentials["api_key"]
}
