output "summary" {
  description = "RunPod fallback summary."
  value = {
    provider     = "runpod"
    worker_count = var.worker_count
    cloud_type   = var.cloud_type
    gpu          = "${var.gpu_count}x [${join(", ", var.gpu_type_ids)}]"
    pod_ids      = runpod_pod.worker[*].id
    pod_names    = runpod_pod.worker[*].name
  }
}
