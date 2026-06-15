output "vault_secret_paths" {
  description = "KV v2 documents Terraform reads at plan/apply time."
  value = {
    azure        = data.vault_kv_secret_v2.azure.name
    runpod       = data.vault_kv_secret_v2.runpod.name
    vultr        = data.vault_kv_secret_v2.vultr.name
    digitalocean = data.vault_kv_secret_v2.digitalocean.name
    rpc          = data.vault_kv_secret_v2.rpc.name
  }
}

output "providers_ready" {
  description = "True when all required key contracts were satisfied."
  value       = length(local.missing_required_keys) == 0
}
