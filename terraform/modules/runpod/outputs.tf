output "pod_ids" {
  description = "RunPod pod IDs."
  value       = runpod_pod.inference[*].id
}
