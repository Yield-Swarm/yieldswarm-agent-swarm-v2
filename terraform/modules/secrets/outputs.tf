output "azure" {
  description = "Azure credentials from Vault."
  value       = local.azure
  sensitive   = true
}

output "runpod" {
  description = "RunPod credentials from Vault."
  value       = local.runpod
  sensitive   = true
}

output "vultr" {
  description = "Vultr credentials from Vault."
  value       = local.vultr
  sensitive   = true
}

output "digitalocean" {
  description = "DigitalOcean credentials from Vault."
  value       = local.digitalocean
  sensitive   = true
}

output "rpc" {
  description = "RPC endpoints from Vault."
  value       = local.rpc
  sensitive   = true
}
