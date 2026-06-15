###############################################################################
# Root module variables.
#
# The variables are grouped into:
#   1. Capacity planning (how much fallback capacity to create)
#   2. Worker runtime configuration (what each worker runs)
#   3. Provider credentials
#   4. Per-provider sizing / placement
###############################################################################

# -----------------------------------------------------------------------------
# 1. Capacity planning
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Deployment environment name, used for tagging and resource naming."
  type        = string
  default     = "helixchainprod"
}

variable "name_prefix" {
  description = "Prefix applied to all fallback resources."
  type        = string
  default     = "yieldswarm-fallback"
}

variable "desired_total_workers" {
  description = "Total number of AgentSwarm worker units the platform wants running across ALL infrastructure (Akash + fallbacks)."
  type        = number
  default     = 120

  validation {
    condition     = var.desired_total_workers >= 0
    error_message = "desired_total_workers must be >= 0."
  }
}

variable "akash_current_workers" {
  description = "Number of worker units Akash is currently serving. The fallback fleet provisions max(0, desired_total_workers - akash_current_workers) equivalent workers across the enabled providers."
  type        = number
  default     = 0

  validation {
    condition     = var.akash_current_workers >= 0
    error_message = "akash_current_workers must be >= 0."
  }
}

variable "enabled_fallbacks" {
  description = "Which fallback providers are allowed to absorb the deficit. Any subset of: azure, gcp, runpod, vultr."
  type        = list(string)
  default     = ["azure", "gcp", "runpod", "vultr"]

  validation {
    condition = alltrue([
      for p in var.enabled_fallbacks : contains(["azure", "gcp", "runpod", "vultr"], p)
    ])
    error_message = "enabled_fallbacks may only contain: azure, gcp, runpod, vultr."
  }
}

variable "fallback_weights" {
  description = "Relative weight used to distribute the worker deficit across enabled providers. Providers not present here default to weight 1."
  type        = map(number)
  default = {
    azure  = 3
    gcp    = 3
    runpod = 2
    vultr  = 2
  }
}

variable "max_workers_per_provider" {
  description = "Hard cap on the number of workers any single provider may be assigned (0 = unlimited). Protects against runaway spend."
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# 2. Worker runtime configuration (shared by every provider)
# -----------------------------------------------------------------------------

variable "worker_container_image" {
  description = "Container image each worker runs (the AgentSwarm worker). Used by VM cloud-init and directly by RunPod pods."
  type        = string
  default     = "ghcr.io/yieldswarm/agentswarm-worker:latest"
}

variable "agents_per_worker" {
  description = "Number of agent shards each worker hosts. Mirrors AGENTS_PER_SHARD from the platform .env."
  type        = number
  default     = 84
}

variable "control_plane_endpoint" {
  description = "URL the worker calls home to (Kimiclaw consensus / OpenClaw control plane)."
  type        = string
  default     = ""
}

variable "worker_env" {
  description = "Extra environment variables injected into every worker container (non-secret). Secrets should be delivered via the provider's secret manager, not here."
  type        = map(string)
  default     = {}
}

variable "ssh_public_key" {
  description = "SSH public key installed on every VM-based worker (Azure, GCP, Vultr) for break-glass access. RunPod pods use the RunPod console."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags/labels applied to all resources where the provider supports them."
  type        = map(string)
  default = {
    project   = "yieldswarm"
    component = "worker-fallback"
    managedby = "terraform"
  }
}

# -----------------------------------------------------------------------------
# 3. Provider credentials
# -----------------------------------------------------------------------------

variable "azure_subscription_id" {
  type    = string
  default = ""
}

variable "azure_tenant_id" {
  type    = string
  default = ""
}

variable "azure_client_id" {
  type    = string
  default = ""
}

variable "azure_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "gcp_project_id" {
  type    = string
  default = ""
}

variable "gcp_credentials_json" {
  description = "Raw GCP service-account JSON. Prefer the GOOGLE_CREDENTIALS env var in CI."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vultr_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "runpod_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

# -----------------------------------------------------------------------------
# 4a. Azure VMSS sizing / placement
# -----------------------------------------------------------------------------

variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "azure_vm_size" {
  description = "VM SKU for the scale set. Use a GPU SKU (e.g. Standard_NC4as_T4_v3) for GPU workers."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "azure_source_image_id" {
  description = "Resource ID of a Packer-built worker image. Empty string falls back to the Ubuntu marketplace image."
  type        = string
  default     = ""
}

variable "azure_resource_group_name" {
  description = "Existing resource group to deploy into. Empty string creates a new one."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# 4b. GCP MIG sizing / placement
# -----------------------------------------------------------------------------

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "gcp_zone" {
  type    = string
  default = "us-central1-a"
}

variable "gcp_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "gcp_gpu_type" {
  description = "Accelerator type for GPU workers (e.g. nvidia-tesla-t4). Empty string = CPU-only."
  type        = string
  default     = ""
}

variable "gcp_gpu_count" {
  type    = number
  default = 0
}

variable "gcp_source_image" {
  description = "Self-link or family of a Packer-built worker image. Empty string uses the Ubuntu LTS family."
  type        = string
  default     = ""
}

variable "gcp_network" {
  type    = string
  default = "default"
}

variable "gcp_subnetwork" {
  type    = string
  default = ""
}

# -----------------------------------------------------------------------------
# 4c. RunPod sizing / placement
# -----------------------------------------------------------------------------

variable "runpod_gpu_type_ids" {
  description = "Ordered preference list of RunPod GPU types."
  type        = list(string)
  default     = ["NVIDIA GeForce RTX 4090", "NVIDIA A40"]
}

variable "runpod_gpu_count" {
  type    = number
  default = 1
}

variable "runpod_data_center_ids" {
  type    = list(string)
  default = []
}

variable "runpod_cloud_type" {
  description = "SECURE or COMMUNITY."
  type        = string
  default     = "COMMUNITY"
}

variable "runpod_container_disk_in_gb" {
  type    = number
  default = 40
}

variable "runpod_volume_in_gb" {
  type    = number
  default = 40
}

# -----------------------------------------------------------------------------
# 4d. Vultr sizing / placement
# -----------------------------------------------------------------------------

variable "vultr_region" {
  type    = string
  default = "ewr"
}

variable "vultr_plan" {
  description = "Vultr plan ID. Use a GPU plan (e.g. vcg-a16-2c-8g-2vram) for GPU workers."
  type        = string
  default     = "vc2-4c-8gb"
}

variable "vultr_os_id" {
  description = "Vultr OS ID (1743 = Ubuntu 22.04 x64). Ignored when vultr_snapshot_id is set."
  type        = number
  default     = 1743
}

variable "vultr_snapshot_id" {
  description = "Packer-built Vultr snapshot ID. Empty string boots from vultr_os_id instead."
  type        = string
  default     = ""
}
