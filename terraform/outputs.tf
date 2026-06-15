# ---------------------------------------------------------------------------
# terraform/outputs.tf
# Non-sensitive outputs only. Secret values are never surfaced here.
# ---------------------------------------------------------------------------

output "azure_container_app_environment_id" {
  description = "Azure Container Apps environment resource ID."
  value       = module.azure.container_app_environment_id
}

output "azure_storage_account_name" {
  description = "Azure Storage Account name for agent state/logs."
  value       = module.azure.storage_account_name
}

output "runpod_pod_ids" {
  description = "IDs of provisioned RunPod GPU pods."
  value       = module.runpod.pod_ids
}

output "vultr_instance_ips" {
  description = "Public IP addresses of Vultr VPS instances."
  value       = module.vultr.instance_ips
}

output "do_droplet_ips" {
  description = "Public IP addresses of DigitalOcean Droplets."
  value       = module.digitalocean.droplet_ips
}

output "do_spaces_bucket_name" {
  description = "DigitalOcean Spaces bucket name for agent storage."
  value       = module.digitalocean.spaces_bucket_name
}

output "do_database_host" {
  description = "DigitalOcean managed PostgreSQL connection host."
  value       = module.digitalocean.database_host
}

output "deployment_summary" {
  description = "High-level summary of deployed resources."
  value = {
    project          = var.project
    environment      = var.environment
    total_agents     = var.total_agents
    shard_count      = var.shard_count
    azure_shards     = var.shard_count
    runpod_pods      = var.runpod_pod_count
    vultr_nodes      = var.vultr_instance_count
    do_droplets      = var.do_droplet_count
  }
}
