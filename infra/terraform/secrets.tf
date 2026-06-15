locals {
  vault_kv_mount = trim(var.vault_kv_mount, "/")
}

data "vault_kv_secret_v2" "azure" {
  mount = local.vault_kv_mount
  name  = var.azure_secret_name
}

data "vault_kv_secret_v2" "runpod" {
  mount = local.vault_kv_mount
  name  = var.runpod_secret_name
}

data "vault_kv_secret_v2" "vultr" {
  mount = local.vault_kv_mount
  name  = var.vultr_secret_name
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = local.vault_kv_mount
  name  = var.digitalocean_secret_name
}

data "vault_kv_secret_v2" "rpc" {
  mount = local.vault_kv_mount
  name  = var.rpc_secret_name
}

locals {
  azure = {
    subscription_id = tostring(data.vault_kv_secret_v2.azure.data["subscription_id"])
    tenant_id       = tostring(data.vault_kv_secret_v2.azure.data["tenant_id"])
    client_id       = tostring(data.vault_kv_secret_v2.azure.data["client_id"])
    client_secret   = tostring(data.vault_kv_secret_v2.azure.data["client_secret"])
  }

  runpod = {
    api_key = tostring(data.vault_kv_secret_v2.runpod.data["api_key"])
  }

  vultr = {
    api_key = tostring(data.vault_kv_secret_v2.vultr.data["api_key"])
  }

  digitalocean = {
    token = tostring(data.vault_kv_secret_v2.digitalocean.data["token"])
  }

  rpc = {
    solana_rpc_url          = tostring(data.vault_kv_secret_v2.rpc.data["solana_rpc_url"])
    failover_rpc_list_json  = tostring(data.vault_kv_secret_v2.rpc.data["failover_rpc_list_json"])
    failover_rpc_list       = jsondecode(tostring(data.vault_kv_secret_v2.rpc.data["failover_rpc_list_json"]))
    helius_api_key          = try(tostring(data.vault_kv_secret_v2.rpc.data["helius_api_key"]), null)
    ethereum_rpc_url        = try(tostring(data.vault_kv_secret_v2.rpc.data["ethereum_rpc_url"]), null)
    base_rpc_url            = try(tostring(data.vault_kv_secret_v2.rpc.data["base_rpc_url"]), null)
    polygon_rpc_url         = try(tostring(data.vault_kv_secret_v2.rpc.data["polygon_rpc_url"]), null)
  }
}
