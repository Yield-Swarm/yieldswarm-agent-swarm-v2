resource "runpod_network_volume" "this" {
  count = var.enabled && var.network_volume_in_gb > 0 ? 1 : 0

  name           = "${var.name}-nv"
  size           = var.network_volume_in_gb
  data_center_id = length(var.data_center_ids) > 0 ? var.data_center_ids[0] : null

  lifecycle {
    precondition {
      condition     = length(var.data_center_ids) > 0
      error_message = "At least one data_center_id is required when creating a RunPod network volume."
    }
  }
}

resource "runpod_pod" "this" {
  count = var.enabled ? 1 : 0

  name                 = var.name
  image_name           = var.image_name
  gpu_type_ids         = var.gpu_type_ids
  data_center_ids      = var.data_center_ids
  gpu_count            = var.gpu_count
  cloud_type           = var.cloud_type
  support_public_ip    = var.support_public_ip
  volume_in_gb         = var.volume_in_gb
  container_disk_in_gb = var.container_disk_in_gb
  volume_mount_path    = var.volume_mount_path

  ports = var.ports
  env   = var.env

  network_volume_id = var.network_volume_in_gb > 0 ? runpod_network_volume.this[0].id : null
}
