# RunPod has no official Terraform provider — use HTTP data source with API key from Vault.
# Validates connectivity and exposes GPU pod configuration for downstream automation.

data "http" "runpod_gpu_types" {
  url = "${local.runpod.endpoint}"

  request_headers = {
    Content-Type  = "application/json"
    Authorization = "Bearer ${local.runpod.api_key}"
  }

  request_body = jsonencode({
    query = <<-GRAPHQL
      query GpuTypes {
        gpuTypes {
          id
          displayName
          memoryInGb
        }
      }
    GRAPHQL
  })

  method = "POST"
}

locals {
  runpod_gpu_types = try(jsondecode(data.http.runpod_gpu_types.response_body).data.gpuTypes, [])
  runpod_selected_gpu = try(
    [for g in local.runpod_gpu_types : g if g.displayName == var.runpod_gpu_type][0],
    null
  )
}

# Output for CI/CD to provision pods via RunPod API (keys never in repo).
output "runpod_config" {
  description = "RunPod configuration derived from Vault secrets"
  value = {
    endpoint    = local.runpod.endpoint
    gpu_type    = var.runpod_gpu_type
    gpu_type_id = try(local.runpod_selected_gpu.id, "unknown")
    api_key_set = local.runpod.api_key != "REPLACE_ME"
  }
  sensitive = false
}
