###############################################################################
# RunPod fallback: one GPU pod per worker unit.
#
# RunPod is container-native, so workers run the AgentSwarm image directly
# (no Packer VM image). Each pod is an independent worker; the count scales with
# the deficit assigned to RunPod.
###############################################################################

terraform {
  required_providers {
    runpod = {
      source = "decentralized-infrastructure/runpod"
    }
  }
}

locals {
  # RunPod pods receive worker identity via env vars; the per-pod index is added
  # so each worker reports a distinct instance id.
  pod_env = {
    for idx in range(var.worker_count) :
    idx => merge(var.worker_env, {
      WORKER_PROVIDER    = "runpod"
      WORKER_INSTANCE_ID = "${var.name_prefix}-rp-${idx}"
    })
  }
}

resource "runpod_pod" "worker" {
  count = var.worker_count

  name                 = "${var.name_prefix}-rp-${count.index}"
  image_name           = var.worker_image
  gpu_type_ids         = var.gpu_type_ids
  gpu_count            = var.gpu_count
  data_center_ids      = length(var.data_center_ids) > 0 ? var.data_center_ids : null
  cloud_type           = var.cloud_type
  support_public_ip    = true
  container_disk_in_gb = var.container_disk_in_gb
  volume_in_gb         = var.volume_in_gb
  ports                = var.ports
  env                  = local.pod_env[count.index]
}
