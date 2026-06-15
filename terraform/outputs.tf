# ============================================================
# Terraform Outputs — YieldSwarm AgentSwarm OS
#
# Only non-sensitive values are output. Never output raw
# secret values — reference them only through sensitive = true
# outputs so Terraform masks them in plan/apply output.
# ============================================================

# ── Azure ─────────────────────────────────────────────────────
output "azure_resource_group_name" {
  description = "Name of the Azure resource group"
  value       = azurerm_resource_group.main.name
}

output "azure_container_registry_login_server" {
  description = "ACR login server URL for docker push/pull"
  value       = azurerm_container_registry.main.login_server
}

output "azure_container_registry_id" {
  description = "Resource ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

output "azure_container_app_fqdn" {
  description = "FQDN of the deployed Azure Container App"
  value       = azurerm_container_app.agentswarm.latest_revision_fqdn
}

output "azure_log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID"
  value       = azurerm_log_analytics_workspace.main.id
}

# ── DigitalOcean ──────────────────────────────────────────────
output "do_droplet_ips" {
  description = "Public IPv4 addresses of all agent Droplets"
  value       = digitalocean_droplet.agent[*].ipv4_address
}

output "do_vpc_id" {
  description = "DigitalOcean VPC ID"
  value       = digitalocean_vpc.main.id
}

output "do_spaces_bucket_domain" {
  description = "DigitalOcean Spaces bucket domain name"
  value       = digitalocean_spaces_bucket.artifacts.bucket_domain_name
}

# ── Vultr ─────────────────────────────────────────────────────
output "vultr_instance_ips" {
  description = "Public IP addresses of all Vultr agent instances"
  value       = vultr_instance.agent[*].main_ip
}

output "vultr_vpc_id" {
  description = "Vultr VPC 2.0 ID"
  value       = vultr_vpc2.main.id
}

# ── RunPod ────────────────────────────────────────────────────
output "runpod_pod_ids" {
  description = "RunPod pod IDs for all provisioned GPU agents"
  value       = runpod_pod.agent[*].id
}

output "runpod_network_volume_id" {
  description = "RunPod network volume ID (shared across pods)"
  value       = runpod_network_volume.agent_data.id
}

# ── Vault AppRole metadata (safe to output — not the secrets) ─
output "vault_terraform_role_id" {
  description = "Vault AppRole Role ID for the yieldswarm-terraform role (not sensitive)"
  value       = var.vault_role_id
  sensitive   = true
}

# ── Summary ───────────────────────────────────────────────────
output "deployment_summary" {
  description = "Human-readable summary of deployed resources"
  value = {
    environment          = var.environment
    azure_app            = azurerm_container_app.agentswarm.name
    azure_registry       = azurerm_container_registry.main.login_server
    do_agents            = length(digitalocean_droplet.agent)
    vultr_agents         = length(vultr_instance.agent)
    runpod_gpu_pods      = length(runpod_pod.agent)
    total_agent_capacity = var.agent_count_total
  }
}
