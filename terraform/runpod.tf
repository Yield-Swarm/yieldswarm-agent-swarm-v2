# =============================================================================
# RunPod Resources
# YieldSwarm AgentSwarm OS v2.0
#
# API key comes from data.vault_kv_secret_v2.runpod (vault-data.tf).
# =============================================================================

resource "runpod_pod" "agentswarm_gpu" {
  name          = "yieldswarm-agentswarm-gpu"
  image_name    = "yieldswarm/agentswarm:latest"
  gpu_type_id   = var.runpod_gpu_type
  gpu_count     = var.runpod_gpu_count
  container_disk_in_gb = 50
  volume_in_gb  = 100
  volume_mount_path = "/data"

  # Vault Agent bootstrap credentials — the container uses these to fetch
  # all remaining secrets from Vault at startup. Only ROLE_ID is non-sensitive.
  env = [
    {
      key   = "VAULT_ADDR"
      value = var.vault_addr
    },
    {
      key   = "VAULT_ENVIRONMENT"
      value = var.vault_environment
    },
    # VAULT_ROLE_ID is stable and non-sensitive (acts like a username)
    {
      key   = "VAULT_ROLE_ID"
      value = data.vault_kv_secret_v2.runpod.data["vault_role_id"]
    },
    # VAULT_SECRET_ID is sensitive; generate a fresh one per deployment using
    # vault/setup/07-rotate-secret-id.sh and store it in Vault at this path.
    {
      key   = "VAULT_SECRET_ID"
      value = data.vault_kv_secret_v2.runpod.data["vault_secret_id"]
    },
  ]

  ports = "8080/http"
}
