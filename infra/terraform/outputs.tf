# =============================================================================
# Root outputs. ALL secret-bearing outputs are flagged sensitive so they never
# show up in plan diffs, CI logs, or `terraform show`.
# =============================================================================

output "azure_resource_group" {
  description = "Name of the Azure resource group provisioned for AgentSwarm."
  value       = try(module.azure[0].resource_group_name, null)
}

output "runpod_pod_ids" {
  description = "RunPod pod IDs created via the REST integration."
  value       = try(module.runpod[0].pod_ids, [])
}

output "vultr_instance_ips" {
  description = "Public IPs of Vultr edge instances."
  value       = try(module.vultr[0].instance_ips, [])
}

output "digitalocean_droplet_ips" {
  description = "Public IPv4 of DigitalOcean droplets."
  value       = try(module.digitalocean[0].droplet_ips, [])
}

output "rpc_endpoints" {
  description = "Map of chain -> primary RPC endpoint URL (no secrets)."
  value       = try(module.rpc[0].endpoint_urls, {})
}

output "rpc_secret_lookup_paths" {
  description = "KV-v2 paths an Akash workload must read to dereference RPC API keys at runtime."
  value       = try(module.rpc[0].secret_paths, {})
}
