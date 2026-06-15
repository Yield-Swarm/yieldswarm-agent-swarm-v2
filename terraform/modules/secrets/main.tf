# Pull all cloud provider and RPC secrets from Vault KV v2 (yieldswarm mount).
# No secret values are defined in Terraform code or tfvars.

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
    tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
    subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
    client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
    resource_group  = data.vault_kv_secret_v2.azure.data["resource_group"]
    location        = data.vault_kv_secret_v2.azure.data["location"]
  }

  runpod = {
    api_key = data.vault_kv_secret_v2.runpod.data["api_key"]
  }

  vultr = {
    api_key = data.vault_kv_secret_v2.vultr.data["api_key"]
  }

  digitalocean = {
    token             = data.vault_kv_secret_v2.digitalocean.data["token"]
    spaces_access_key = try(data.vault_kv_secret_v2.digitalocean.data["spaces_access_key"], "")
    spaces_secret_key = try(data.vault_kv_secret_v2.digitalocean.data["spaces_secret_key"], "")
  }

  rpc = {
    solana_rpc_url    = data.vault_kv_secret_v2.rpc.data["solana_rpc_url"]
    helius_api_key    = data.vault_kv_secret_v2.rpc.data["helius_api_key"]
    failover_rpc_list = data.vault_kv_secret_v2.rpc.data["failover_rpc_list"]
  }
}

output "azure" {
  description = "Azure credentials from Vault (sensitive)."
  value       = local.azure
  sensitive   = true
}

output "runpod" {
  description = "RunPod credentials from Vault (sensitive)."
  value       = local.runpod
  sensitive   = true
}

output "vultr" {
  description = "Vultr credentials from Vault (sensitive)."
  value       = local.vultr
  sensitive   = true
}

output "digitalocean" {
  description = "DigitalOcean credentials from Vault (sensitive)."
  value       = local.digitalocean
  sensitive   = true
}

output "rpc" {
  description = "RPC endpoints from Vault (sensitive)."
  value       = local.rpc
  sensitive   = true
}
