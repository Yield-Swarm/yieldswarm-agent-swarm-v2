output "pod_id" {
  value = var.enabled ? runpod_pod.this[0].id : null
}

output "pod_desired_status" {
  value = var.enabled ? runpod_pod.this[0].desired_status : null
}

output "network_volume_id" {
  value = var.enabled && var.network_volume_in_gb > 0 ? runpod_network_volume.this[0].id : null
}
