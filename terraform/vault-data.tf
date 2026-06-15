# All cloud and RPC secrets are read from Vault KV v2 at plan/apply time.
# No secrets are stored in Terraform state beyond what providers require.

data "vault_kv_secret_v2" "azure" {
  mount = "yieldswarm"
  name  = "azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = "yieldswarm"
  name  = "runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = "yieldswarm"
  name  = "vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = "yieldswarm"
  name  = "digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  mount = "yieldswarm"
  name  = "rpc"
}

locals {
  azure = {
    subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
    client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
    tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
    resource_group  = var.azure_resource_group_name != "" ? var.azure_resource_group_name : data.vault_kv_secret_v2.azure.data["resource_group"]
    location        = var.azure_location != "" ? var.azure_location : data.vault_kv_secret_v2.azure.data["location"]
  }

  runpod = {
    api_key  = data.vault_kv_secret_v2.runpod.data["api_key"]
    endpoint = data.vault_kv_secret_v2.runpod.data["endpoint"]
  }

  vultr = {
    api_key = data.vault_kv_secret_v2.vultr.data["api_key"]
  }

  digitalocean = {
    token             = data.vault_kv_secret_v2.digitalocean.data["token"]
    spaces_access_key = data.vault_kv_secret_v2.digitalocean.data["spaces_access_key"]
    spaces_secret_key = data.vault_kv_secret_v2.digitalocean.data["spaces_secret_key"]
    spaces_region     = data.vault_kv_secret_v2.digitalocean.data["spaces_region"]
  }

  rpc = {
    solana_rpc_url    = data.vault_kv_secret_v2.rpc.data["solana_rpc_url"]
    helius_api_key    = data.vault_kv_secret_v2.rpc.data["helius_api_key"]
    failover_rpc_list = data.vault_kv_secret_v2.rpc.data["failover_rpc_list"]
    birdeye_api_key   = data.vault_kv_secret_v2.rpc.data["birdeye_api_key"]
    jupiter_api_key   = data.vault_kv_secret_v2.rpc.data["jupiter_api_key"]
  }

  common_tags = merge(var.tags, { environment = var.environment })
}
