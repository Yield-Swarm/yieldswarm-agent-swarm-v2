output "azure_resource_group" {
  description = "Name of the YieldSwarm Azure resource group, or null when disabled."
  value       = try(module.azure[0].resource_group_name, null)
}

output "vultr_account" {
  description = "Vultr account name — confirms credential validity, or null when disabled."
  value       = try(module.vultr[0].account_name, null)
}

output "digitalocean_regions" {
  description = "DO regions accepting Droplets, or null when disabled."
  value       = try(module.digitalocean[0].available_region_slugs, null)
}

output "runpod_verified" {
  description = "True if the RunPod API key was live-verified during plan."
  value       = try(module.runpod[0].verified, false)
}

output "rpc_chains" {
  description = "Chains successfully loaded from Vault."
  value       = keys(module.rpc.endpoints)
}
