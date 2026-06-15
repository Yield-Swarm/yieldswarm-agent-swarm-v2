provider "runpod" {
  api_key = local.runpod_creds["api_key"]
}

resource "runpod_pod" "agent_gpu" {
  name       = "yieldswarm-agent-gpu"
  image_name = "ghcr.io/yieldswarm/agentswarm:latest"

  gpu_type_ids = [var.runpod_gpu_type]
  gpu_count    = 1
  cloud_type   = "SECURE"

  container_disk_in_gb = 10
  volume_in_gb         = 20
  volume_mount_path    = "/run/yieldswarm"

  ports = ["8080/http"]

  env = {
    VAULT_ADDR       = var.vault_addr
    VAULT_ROLE_ID    = var.vault_role_id
    VAULT_SECRET_ID  = var.vault_secret_id
    SOLANA_RPC_URL   = local.solana_rpc_url
    AGENT_MODULE     = "agents.akash_optimizer"
    AGENT_SHARD_ID   = "0"
  }
}
