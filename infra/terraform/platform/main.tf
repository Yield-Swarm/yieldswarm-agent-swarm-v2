provider "vault" {
  skip_child_token = true
}

locals {
  platform_secret_paths = {
    azure        = "${var.environment}/azure"
    runpod       = "${var.environment}/runpod"
    vultr        = "${var.environment}/vultr"
    digitalocean = "${var.environment}/digitalocean"
    rpc          = "${var.environment}/rpc"
  }

  runtime_secret_path = "${var.application_name}/${var.environment}"
}

data "vault_kv_secret_v2" "azure" {
  mount = var.platform_mount_path
  name  = local.platform_secret_paths.azure
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.platform_mount_path
  name  = local.platform_secret_paths.runpod
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.platform_mount_path
  name  = local.platform_secret_paths.vultr
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.platform_mount_path
  name  = local.platform_secret_paths.digitalocean
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.platform_mount_path
  name  = local.platform_secret_paths.rpc
}

data "vault_kv_secret_v2" "app_runtime" {
  mount = var.runtime_mount_path
  name  = local.runtime_secret_path
}

locals {
  azure_credentials = {
    subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
    tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
    client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
  }

  runpod_api_key = data.vault_kv_secret_v2.runpod.data["api_key"]

  vultr_api_key = data.vault_kv_secret_v2.vultr.data["api_key"]

  digitalocean_token = data.vault_kv_secret_v2.digitalocean.data["token"]

  rpc = {
    primary_url   = data.vault_kv_secret_v2.rpc.data["primary_url"]
    websocket_url = try(data.vault_kv_secret_v2.rpc.data["websocket_url"], null)
    auth_header   = try(data.vault_kv_secret_v2.rpc.data["auth_header"], null)
    failover_urls = try(jsondecode(data.vault_kv_secret_v2.rpc.data["failover_urls"]), [])
  }
}

provider "azurerm" {
  features {}

  subscription_id = local.azure_credentials.subscription_id
  tenant_id       = local.azure_credentials.tenant_id
  client_id       = local.azure_credentials.client_id
  client_secret   = local.azure_credentials.client_secret
}

provider "digitalocean" {
  token = local.digitalocean_token
}

provider "vultr" {
  api_key     = local.vultr_api_key
  rate_limit  = 100
  retry_limit = 3
}

provider "runpod" {
  api_key = local.runpod_api_key
}

output "vault_secret_paths" {
  description = "Vault paths consumed by Terraform."
  value = {
    azure              = "${var.platform_mount_path}/${local.platform_secret_paths.azure}"
    runpod             = "${var.platform_mount_path}/${local.platform_secret_paths.runpod}"
    vultr              = "${var.platform_mount_path}/${local.platform_secret_paths.vultr}"
    digitalocean       = "${var.platform_mount_path}/${local.platform_secret_paths.digitalocean}"
    rpc                = "${var.platform_mount_path}/${local.platform_secret_paths.rpc}"
    application_runtime = "${var.runtime_mount_path}/${local.runtime_secret_path}"
  }
}

output "rpc_configuration" {
  description = "RPC configuration loaded from Vault for downstream modules."
  value       = local.rpc
  sensitive   = true
}

output "app_runtime_secret_version" {
  description = "Current runtime secret version observed by Terraform."
  value       = data.vault_kv_secret_v2.app_runtime.version
}
