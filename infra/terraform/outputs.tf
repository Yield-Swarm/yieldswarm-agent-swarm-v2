# Outputs are deliberately metadata-only. Secret values stay in Vault;
# anything that needs them at runtime authenticates to Vault directly.

output "azure_resource_group" {
  description = "Resource group that hosts the APN Azure footprint."
  value       = module.azure.resource_group_name
}

output "runpod_pod_ids" {
  description = "IDs of RunPod GPU pods managed by Terraform."
  value       = module.runpod.pod_ids
}

output "vultr_instance_ids" {
  description = "IDs of Vultr compute instances managed by Terraform."
  value       = module.vultr.instance_ids
}

output "digitalocean_droplet_ids" {
  description = "IDs of DigitalOcean droplets managed by Terraform."
  value       = module.digitalocean.droplet_ids
}

output "rpc_chain_inventory" {
  description = "Chains for which RPC secrets have been wired into the platform."
  value       = module.rpc.chain_inventory
}
