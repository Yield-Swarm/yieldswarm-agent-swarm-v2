## RunPod module - provisions a GPU pod for AgentSwarm inference shards.
## The RunPod provider authenticates via `api_key` configured at the root.

terraform {
  required_providers {
    runpod = {
      source  = "runpod/runpod"
      version = ">= 1.0"
    }
  }
}

resource "runpod_pod" "inference" {
  name                 = "yieldswarm-inference-${var.environment}"
  image_name           = "runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04"
  gpu_type_id          = "NVIDIA RTX A6000"
  gpu_count            = 1
  cloud_type           = "SECURE"
  container_disk_in_gb = 50
  volume_in_gb         = 100
  volume_mount_path    = "/workspace"
  ports                = "22/tcp,8000/http"
  start_ssh            = true

  # Pod template (with vault-agent sidecar) is managed out-of-band and
  # referenced by ID so this module never embeds image-bound secrets.
  template_id = var.pod_template_id
}
