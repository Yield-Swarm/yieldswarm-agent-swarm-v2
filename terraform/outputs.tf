output "azure_resource_group" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.yieldswarm.name
}

output "azure_container_app_environment_id" {
  description = "ID of the Azure Container App Environment hosting agent shards."
  value       = azurerm_container_app_environment.agents.id
}

output "do_dashboard_ips" {
  description = "DigitalOcean dashboard droplet IPs."
  value       = digitalocean_droplet.dashboard[*].ipv4_address
}

output "vultr_cron_ips" {
  description = "Vultr cron-runner instance IPs."
  value       = vultr_instance.cron_runner[*].main_ip
}

output "kv_mount_used" {
  description = "Vault KVv2 mount that this stack is reading from."
  value       = var.vault_kv_mount
}
