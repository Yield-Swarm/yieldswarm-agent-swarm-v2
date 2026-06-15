# ---------------------------------------------------------------------------
# modules/runpod/main.tf
# RunPod GPU pods for AI inference workloads.
# API key is never hardcoded — it flows from the Vault data source in
# the root module through the provider configuration.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "runpod_pod" "inference" {
  count = var.pod_count

  name          = "${local.name_prefix}-gpu-${count.index}"
  image_name    = var.agent_image
  gpu_type_id   = var.gpu_type
  gpu_count     = var.gpu_count
  container_disk_in_gb = var.container_disk

  # Vault credentials injected as environment variables at container start
  env = [
    {
      key   = "VAULT_ADDR"
      value = var.vault_addr
    },
    {
      key   = "VAULT_ROLE_ID"
      value = var.vault_approle_role_id
    },
    {
      key   = "VAULT_SECRET_ID"
      value = var.vault_approle_secret_id
    },
    {
      key   = "AGENT_MODE"
      value = "gpu-inference"
    },
  ]

  # Attach persistent network volume if provided
  dynamic "volume_in_gb" {
    for_each = var.network_volume_id != "" ? [1] : []
    content {
      # volume mount path — adjust as needed
    }
  }

  ports = "8080/http"
}
