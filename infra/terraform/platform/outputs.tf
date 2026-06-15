output "azure_tenant_id" {
  description = "Azure tenant ID loaded from Vault."
  value       = local.azure_creds.tenant_id
}

output "azure_subscription_id" {
  description = "Azure subscription ID loaded from Vault."
  value       = local.azure_creds.subscription_id
}

output "digitalocean_email" {
  description = "DigitalOcean account email proving provider auth succeeded."
  value       = data.digitalocean_account.current.email
}

output "vultr_name" {
  description = "Vultr account name proving provider auth succeeded."
  value       = data.vultr_account.current.name
}

output "rpc_primary_url" {
  description = "Primary RPC URL loaded from Vault."
  value       = local.rpc_config.primary_url
  sensitive   = true
}
