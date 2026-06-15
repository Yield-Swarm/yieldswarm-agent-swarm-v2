output "azure_resource_group" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.agents.name
}

output "azure_container_app_fqdn" {
  description = "Internal FQDN for the orchestrator container app."
  value       = azurerm_container_app.orchestrator.ingress[0].fqdn
}

output "runpod_pod_id" {
  description = "RunPod pod ID for GPU agent workload."
  value       = runpod_pod.agent_gpu.id
}

output "vultr_instance_ip" {
  description = "Public IP of Vultr agent node."
  value       = vultr_instance.agent_node.main_ip
}

output "digitalocean_droplet_ip" {
  description = "Public IP of DigitalOcean agent node."
  value       = digitalocean_droplet.agent_node.ipv4_address
}
