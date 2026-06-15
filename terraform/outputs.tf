# terraform/outputs.tf
# Infrastructure outputs. No secret values are exposed here.

output "vault_addr" {
  description = "Vault server address used by this Terraform run."
  value       = var.vault_addr
}

# Azure
output "azure_resource_group_name" {
  description = "Azure resource group."
  value       = azurerm_resource_group.main.name
}

output "azure_container_app_url" {
  description = "Public URL of the Azure Container App."
  value       = "https://${azurerm_container_app.agents.ingress[0].fqdn}"
}

# DigitalOcean
output "digitalocean_coordinator_ip" {
  description = "Public IP of the DigitalOcean coordinator Droplet."
  value       = digitalocean_droplet.coordinator.ipv4_address
}

output "digitalocean_spaces_endpoint" {
  description = "DigitalOcean Spaces bucket domain."
  value       = digitalocean_spaces_bucket.agent_state.bucket_domain_name
}

# Vultr
output "vultr_coordinator_ip" {
  description = "Public IP of the Vultr coordinator instance."
  value       = vultr_instance.coordinator.main_ip
}

# RunPod
output "runpod_next_steps" {
  description = "Instructions for completing RunPod pod setup."
  value       = "Visit console.runpod.io, find pod '${var.runpod_pod_name}', and set VAULT_ROLE_ID + VAULT_SECRET_ID."
}
