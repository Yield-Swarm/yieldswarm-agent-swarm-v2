provider "vault" {
  address   = var.vault_addr
  token     = var.vault_token
  namespace = var.vault_namespace
}

data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount_path
  name  = var.azure_secret_path
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount_path
  name  = var.runpod_secret_path
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount_path
  name  = var.vultr_secret_path
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount_path
  name  = var.digitalocean_secret_path
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount_path
  name  = var.rpc_secret_path
}

locals {
  azure_creds        = data.vault_kv_secret_v2.azure.data
  runpod_creds       = data.vault_kv_secret_v2.runpod.data
  vultr_creds        = data.vault_kv_secret_v2.vultr.data
  digitalocean_creds = data.vault_kv_secret_v2.digitalocean.data
  rpc_config         = data.vault_kv_secret_v2.rpc.data

  required_azure_keys        = ["tenant_id", "subscription_id", "client_id", "client_secret"]
  required_runpod_keys       = ["api_key"]
  required_vultr_keys        = ["api_key"]
  required_digitalocean_keys = ["token"]
  required_rpc_keys          = ["primary_url"]
}

check "azure_secret_has_required_keys" {
  assert {
    condition     = alltrue([for k in local.required_azure_keys : try(trim(local.azure_creds[k]) != "", false)])
    error_message = "Vault secret ${var.vault_kv_mount_path}/${var.azure_secret_path} must contain tenant_id, subscription_id, client_id, and client_secret."
  }
}

check "runpod_secret_has_required_keys" {
  assert {
    condition     = alltrue([for k in local.required_runpod_keys : try(trim(local.runpod_creds[k]) != "", false)])
    error_message = "Vault secret ${var.vault_kv_mount_path}/${var.runpod_secret_path} must contain api_key."
  }
}

check "vultr_secret_has_required_keys" {
  assert {
    condition     = alltrue([for k in local.required_vultr_keys : try(trim(local.vultr_creds[k]) != "", false)])
    error_message = "Vault secret ${var.vault_kv_mount_path}/${var.vultr_secret_path} must contain api_key."
  }
}

check "digitalocean_secret_has_required_keys" {
  assert {
    condition     = alltrue([for k in local.required_digitalocean_keys : try(trim(local.digitalocean_creds[k]) != "", false)])
    error_message = "Vault secret ${var.vault_kv_mount_path}/${var.digitalocean_secret_path} must contain token."
  }
}

check "rpc_secret_has_required_keys" {
  assert {
    condition     = alltrue([for k in local.required_rpc_keys : try(trim(local.rpc_config[k]) != "", false)])
    error_message = "Vault secret ${var.vault_kv_mount_path}/${var.rpc_secret_path} must contain at least primary_url."
  }
}

provider "azurerm" {
  features {}

  tenant_id       = local.azure_creds.tenant_id
  subscription_id = local.azure_creds.subscription_id
  client_id       = local.azure_creds.client_id
  client_secret   = local.azure_creds.client_secret
}

provider "runpod" {
  api_key = local.runpod_creds.api_key
}

provider "vultr" {
  api_key = local.vultr_creds.api_key
}

provider "digitalocean" {
  token = local.digitalocean_creds.token
}

# Example data sources to validate provider authentication at plan time.
data "azurerm_client_config" "current" {}

data "digitalocean_account" "current" {}

data "vultr_account" "current" {}
