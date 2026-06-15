# Typed, sensitive outputs. Downstream modules consume these.

output "azure" {
  description = "Azure SP credentials sourced from Vault."
  sensitive   = true
  value = {
    client_id       = try(data.vault_kv_secret_v2.azure.data["client_id"], null)
    client_secret   = try(data.vault_kv_secret_v2.azure.data["client_secret"], null)
    tenant_id       = try(data.vault_kv_secret_v2.azure.data["tenant_id"], null)
    subscription_id = try(data.vault_kv_secret_v2.azure.data["subscription_id"], null)
  }
}

output "runpod" {
  description = "RunPod API credentials sourced from Vault."
  sensitive   = true
  value = {
    api_key = try(data.vault_kv_secret_v2.runpod.data["api_key"], null)
  }
}

output "vultr" {
  description = "Vultr API credentials sourced from Vault."
  sensitive   = true
  value = {
    api_key = try(data.vault_kv_secret_v2.vultr.data["api_key"], null)
  }
}

output "digitalocean" {
  description = "DigitalOcean API + Spaces credentials sourced from Vault."
  sensitive   = true
  value = {
    token             = try(data.vault_kv_secret_v2.digitalocean.data["token"], null)
    spaces_access_id  = try(data.vault_kv_secret_v2.digitalocean.data["spaces_access_id"], null)
    spaces_secret_key = try(data.vault_kv_secret_v2.digitalocean.data["spaces_secret_key"], null)
  }
}

output "rpc" {
  description = "Per-chain RPC URLs and API keys. Map<chain_name, map<key,value>>."
  sensitive   = true
  value = {
    for chain, src in data.vault_kv_secret_v2.rpc :
    chain => src.data
  }
}
