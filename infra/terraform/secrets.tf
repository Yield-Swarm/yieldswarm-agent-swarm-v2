data "vault_kv_secret_v2" "azure" {
  mount = var.vault_cloud_mount
  name  = "terraform/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_cloud_mount
  name  = "terraform/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_cloud_mount
  name  = "terraform/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_cloud_mount
  name  = "terraform/digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_cloud_mount
  name  = "terraform/rpc"
}

locals {
  azure_subscription_id = try(data.vault_kv_secret_v2.azure.data["subscription_id"], null)
  azure_client_id       = try(data.vault_kv_secret_v2.azure.data["client_id"], null)
  azure_client_secret   = try(data.vault_kv_secret_v2.azure.data["client_secret"], null)
  azure_tenant_id       = try(data.vault_kv_secret_v2.azure.data["tenant_id"], null)

  runpod_api_key = try(data.vault_kv_secret_v2.runpod.data["api_key"], null)

  vultr_api_key = try(data.vault_kv_secret_v2.vultr.data["api_key"], null)

  do_token = try(data.vault_kv_secret_v2.digitalocean.data["token"], null)

  rpc_primary_url = try(data.vault_kv_secret_v2.rpc.data["primary_url"], null)
  rpc_backup_url  = try(data.vault_kv_secret_v2.rpc.data["backup_url"], null)
}
