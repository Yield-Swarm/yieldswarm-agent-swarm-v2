data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.azure
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.runpod
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.vultr
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.digitalocean
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.rpc
}

locals {
  azure        = data.vault_kv_secret_v2.azure.data
  runpod       = data.vault_kv_secret_v2.runpod.data
  vultr        = data.vault_kv_secret_v2.vultr.data
  digitalocean = data.vault_kv_secret_v2.digitalocean.data
  rpc          = data.vault_kv_secret_v2.rpc.data

  required_secret_keys = {
    azure        = ["ARM_CLIENT_ID", "ARM_CLIENT_SECRET", "ARM_TENANT_ID", "ARM_SUBSCRIPTION_ID"]
    runpod       = ["RUNPOD_API_KEY"]
    vultr        = ["VULTR_API_KEY"]
    digitalocean = ["DIGITALOCEAN_TOKEN"]
    rpc          = ["SOLANA_RPC_URL"]
  }

  loaded_secret_maps = {
    azure        = local.azure
    runpod       = local.runpod
    vultr        = local.vultr
    digitalocean = local.digitalocean
    rpc          = local.rpc
  }

  missing_secret_keys = flatten([
    for secret_name, required_keys in local.required_secret_keys : [
      for key in required_keys : "${secret_name}.${key}"
      if !contains(keys(local.loaded_secret_maps[secret_name]), key)
    ]
  ])
}

check "vault_secret_schema" {
  assert {
    condition     = length(local.missing_secret_keys) == 0
    error_message = "Missing required Vault keys: ${join(", ", local.missing_secret_keys)}."
  }
}
