locals {
  vault_kv_mount_path = trimsuffix(var.vault_kv_mount_path, "/")
}

data "vault_kv_secret_v2" "azure" {
  mount = local.vault_kv_mount_path
  name  = var.azure_secret_path
}

data "vault_kv_secret_v2" "runpod" {
  mount = local.vault_kv_mount_path
  name  = var.runpod_secret_path
}

data "vault_kv_secret_v2" "vultr" {
  mount = local.vault_kv_mount_path
  name  = var.vultr_secret_path
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = local.vault_kv_mount_path
  name  = var.digitalocean_secret_path
}

data "vault_kv_secret_v2" "rpc" {
  mount = local.vault_kv_mount_path
  name  = var.rpc_secret_path
}

locals {
  azure_required_keys        = ["subscription_id", "tenant_id", "client_id", "client_secret"]
  runpod_required_keys       = ["api_key"]
  vultr_required_keys        = ["api_key"]
  digitalocean_required_keys = ["token"]
  rpc_required_keys          = ["SOLANA_RPC_URL", "FAILOVER_RPC_LIST"]

  azure_missing_keys = [
    for key in local.azure_required_keys : key
    if !contains(keys(data.vault_kv_secret_v2.azure.data), key)
  ]
  runpod_missing_keys = [
    for key in local.runpod_required_keys : key
    if !contains(keys(data.vault_kv_secret_v2.runpod.data), key)
  ]
  vultr_missing_keys = [
    for key in local.vultr_required_keys : key
    if !contains(keys(data.vault_kv_secret_v2.vultr.data), key)
  ]
  digitalocean_missing_keys = [
    for key in local.digitalocean_required_keys : key
    if !contains(keys(data.vault_kv_secret_v2.digitalocean.data), key)
  ]
  rpc_missing_keys = [
    for key in local.rpc_required_keys : key
    if !contains(keys(data.vault_kv_secret_v2.rpc.data), key)
  ]

  azure = {
    subscription_id = try(data.vault_kv_secret_v2.azure.data["subscription_id"], null)
    tenant_id       = try(data.vault_kv_secret_v2.azure.data["tenant_id"], null)
    client_id       = try(data.vault_kv_secret_v2.azure.data["client_id"], null)
    client_secret   = try(data.vault_kv_secret_v2.azure.data["client_secret"], null)
  }

  runpod = {
    api_key = try(data.vault_kv_secret_v2.runpod.data["api_key"], null)
  }

  vultr = {
    api_key = try(data.vault_kv_secret_v2.vultr.data["api_key"], null)
  }

  digitalocean = {
    token = try(data.vault_kv_secret_v2.digitalocean.data["token"], null)
  }

  rpc = data.vault_kv_secret_v2.rpc.data
}

check "vault_secret_schema" {
  assert {
    condition     = length(local.azure_missing_keys) == 0
    error_message = "Vault secret ${local.vault_kv_mount_path}/${var.azure_secret_path} is missing keys: ${join(", ", local.azure_missing_keys)}"
  }

  assert {
    condition     = length(local.runpod_missing_keys) == 0
    error_message = "Vault secret ${local.vault_kv_mount_path}/${var.runpod_secret_path} is missing keys: ${join(", ", local.runpod_missing_keys)}"
  }

  assert {
    condition     = length(local.vultr_missing_keys) == 0
    error_message = "Vault secret ${local.vault_kv_mount_path}/${var.vultr_secret_path} is missing keys: ${join(", ", local.vultr_missing_keys)}"
  }

  assert {
    condition     = length(local.digitalocean_missing_keys) == 0
    error_message = "Vault secret ${local.vault_kv_mount_path}/${var.digitalocean_secret_path} is missing keys: ${join(", ", local.digitalocean_missing_keys)}"
  }

  assert {
    condition     = length(local.rpc_missing_keys) == 0
    error_message = "Vault secret ${local.vault_kv_mount_path}/${var.rpc_secret_path} is missing keys: ${join(", ", local.rpc_missing_keys)}"
  }
}
