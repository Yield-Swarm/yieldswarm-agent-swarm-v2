# RunPod GPU workloads — API key from Vault.
# Set runpod_create_pod = true only when actively provisioning.

resource "runpod_pod" "gpu_worker" {
  count = var.runpod_create_pod ? 1 : 0

  name              = "${var.project_name}-${var.environment}-gpu"
  image_name        = "runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel-ubuntu22.04"
  gpu_type_ids      = [local.runpod_secrets.default_gpu_type]
  cloud_type        = "SECURE"
  support_public_ip = false

  env = {
    VAULT_SECRETS_SOURCE = "injected-at-runtime"
    SOLANA_RPC_URL       = local.rpc_secrets.solana_rpc_url
    HELIUS_API_KEY       = local.rpc_secrets.helius_api_key
  }
}

output "runpod_default_gpu" {
  description = "Default GPU type from Vault."
  value       = nonsensitive(local.runpod_secrets.default_gpu_type)
}

output "runpod_default_region" {
  description = "Default RunPod region from Vault."
  value       = nonsensitive(local.runpod_secrets.default_region)
}

output "runpod_pod_id" {
  description = "RunPod pod ID when provisioned."
  value       = try(runpod_pod.gpu_worker[0].id, null)
  sensitive   = true
}
