# =============================================================================
# Outputs. All credential outputs are marked sensitive so they never appear
# in CI logs. Consumers (Akash deployment pipeline) should read them via
# `terraform output -json -raw` and pipe directly into Vault or the Akash CLI.
# =============================================================================

output "azure_resource_group" {
  description = "Azure resource group name (only set when Azure is enabled)."
  value       = var.enabled_clouds.azure ? azurerm_resource_group.main[0].name : null
}

output "azure_key_vault_uri" {
  description = "Azure Key Vault URI mirroring the RPC bundle."
  value       = var.enabled_clouds.azure ? azurerm_key_vault.rpc_mirror[0].vault_uri : null
}

output "vultr_instance_ips" {
  description = "Public IPs of provisioned Vultr instances."
  value       = var.enabled_clouds.vultr ? vultr_instance.agent_node[*].main_ip : []
}

output "digitalocean_droplet_ips" {
  description = "Public IPs of provisioned DigitalOcean droplets."
  value       = var.enabled_clouds.digitalocean ? digitalocean_droplet.agent_node[*].ipv4_address : []
}

output "digitalocean_spaces_endpoint" {
  description = "DigitalOcean Spaces endpoint hosting the cron artifacts bucket."
  value       = var.enabled_clouds.digitalocean ? digitalocean_spaces_bucket.cron_artifacts[0].endpoint : null
}

output "runpod_template_id" {
  description = "RunPod pod template id registered for the YieldSwarm agents."
  value       = var.enabled_clouds.runpod ? jsondecode(restapi_object.yieldswarm_pod_template[0].api_response).data.saveTemplate.id : null
}

output "rpc_endpoint_count" {
  description = "Number of RPC keys mirrored from Vault (sanity check, no values)."
  value       = length(local.rpc_safe)
}

# Sensitive: full RPC bundle for piping into Akash SDL env block. Marked
# sensitive so it never lands in plan/apply stdout.
output "rpc_bundle" {
  description = "All RPC values pulled from Vault. SENSITIVE."
  value       = local.rpc_safe
  sensitive   = true
}
