# ============================================================
# RunPod Infrastructure — YieldSwarm AgentSwarm OS
#
# Resources:
#   - RunPod Network Volume (persistent storage for model
#     weights and agent checkpoints)
#   - RunPod GPU Pod(s) for compute-heavy agent shards
#     (Gensyn, GPU mining, inference workloads)
#
# All credentials come from data.vault_generic_secret.runpod
# ============================================================

# ── Network volume (persistent storage) ──────────────────────
resource "runpod_network_volume" "agent_data" {
  name          = "${var.project_name}-agent-data-${var.environment}"
  size          = var.runpod_volume_size_gb
  datacenter_id = var.runpod_datacenter_id
}

# ── GPU Pod(s) ────────────────────────────────────────────────
# The container reads secrets from Vault via the same
# entrypoint pattern used in the Akash deployment.
resource "runpod_pod" "agent" {
  count = var.runpod_pod_count

  name          = "${var.project_name}-agent-${var.environment}-${count.index + 1}"
  image_name    = var.runpod_container_image
  gpu_type_id   = var.runpod_gpu_type

  # Minimum GPU count per pod
  gpu_count = 1

  container_disk_in_gb = 20
  volume_in_gb         = var.runpod_volume_size_gb
  volume_mount_path    = "/workspace/data"

  network_volume_id = runpod_network_volume.agent_data.id

  # Only Vault bootstrap credentials injected at launch.
  # All other secrets pulled by entrypoint.sh at runtime.
  env = [
    "VAULT_ADDR=${var.vault_address}",
    "VAULT_ROLE_ID=${var.vault_role_id}",
    "VAULT_SECRET_ID=${var.vault_secret_id}",
    "ENVIRONMENT=${var.environment}",
    "AGENT_COUNT_TOTAL=${var.agent_count_total}",
    "AGENTS_PER_SHARD=${var.agents_per_shard}",
    "POD_INDEX=${count.index}",
  ]

  ports = "8080/http"

  # Spot instances for cost optimization on non-critical shards
  # Set to false for critical/consensus nodes
  cloud_type = var.runpod_use_spot ? "SECURE" : "ALL"
}

# ── Additional variables ──────────────────────────────────────
variable "runpod_datacenter_id" {
  description = "RunPod datacenter ID (e.g. US-TX-3)"
  type        = string
  default     = "US-TX-3"
}

variable "runpod_volume_size_gb" {
  description = "Size of the RunPod network volume in GB"
  type        = number
  default     = 50
}

variable "runpod_container_image" {
  description = "Container image for RunPod pods (must be accessible from RunPod)"
  type        = string
  default     = "yieldswarm/agentswarm:latest"
}

variable "runpod_use_spot" {
  description = "Use RunPod spot/community instances for cost savings"
  type        = bool
  default     = false
}
