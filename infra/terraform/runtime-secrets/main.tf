data "vault_kv_secret_v2" "azure" {
  mount = var.kv_mount_path
  name  = var.azure_secret_path
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.kv_mount_path
  name  = var.runpod_secret_path
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.kv_mount_path
  name  = var.vultr_secret_path
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.kv_mount_path
  name  = var.digitalocean_secret_path
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.kv_mount_path
  name  = var.rpc_secret_path
}

locals {
  azure = {
    subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
    tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
    client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
  }

  runpod = {
    api_key     = data.vault_kv_secret_v2.runpod.data["api_key"]
    endpoint_id = lookup(data.vault_kv_secret_v2.runpod.data, "endpoint_id", null)
  }

  vultr = {
    api_key = data.vault_kv_secret_v2.vultr.data["api_key"]
    region  = lookup(data.vault_kv_secret_v2.vultr.data, "region", null)
  }

  digitalocean = {
    token  = data.vault_kv_secret_v2.digitalocean.data["token"]
    region = lookup(data.vault_kv_secret_v2.digitalocean.data, "region", null)
  }

  rpc = {
    primary_rpc_url = data.vault_kv_secret_v2.rpc.data["primary_rpc_url"]
    solana_rpc_url  = lookup(data.vault_kv_secret_v2.rpc.data, "solana_rpc_url", null)
    ethereum_rpc_url = lookup(data.vault_kv_secret_v2.rpc.data, "ethereum_rpc_url", null)
    polygon_rpc_url = lookup(data.vault_kv_secret_v2.rpc.data, "polygon_rpc_url", null)
    helius_api_key  = lookup(data.vault_kv_secret_v2.rpc.data, "helius_api_key", null)
  }

  # Downstream Terraform modules should consume this object instead of reading
  # environment variables or checked-in tfvars files.
  provider_secrets = {
    azure        = local.azure
    runpod       = local.runpod
    vultr        = local.vultr
    digitalocean = local.digitalocean
    rpc          = local.rpc
  }
}
