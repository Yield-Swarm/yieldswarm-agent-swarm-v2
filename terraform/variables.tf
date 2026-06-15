# ============================================================
# Input Variables — YieldSwarm Terraform
#
# Only non-sensitive configuration lives here. All cloud-
# provider credentials are read from Vault at runtime.
# ============================================================

# ── Vault connection ──────────────────────────────────────────
variable "vault_address" {
  description = "URL of the Vault cluster (e.g. https://vault.yieldswarm.internal:8200)"
  type        = string
  # Set via TF_VAR_vault_address or terraform.tfvars
}

variable "vault_role_id" {
  description = "AppRole Role ID for the yieldswarm-terraform role"
  type        = string
  sensitive   = true
  # Set via TF_VAR_vault_role_id environment variable — never in tfvars
}

variable "vault_secret_id" {
  description = "AppRole Secret ID for the yieldswarm-terraform role"
  type        = string
  sensitive   = true
  # Set via TF_VAR_vault_secret_id environment variable — never in tfvars
}

variable "vault_skip_tls_verify" {
  description = "Skip Vault TLS certificate verification (dev/staging only — never in prod)"
  type        = bool
  default     = false
}

# ── Project / environment metadata ───────────────────────────
variable "project_name" {
  description = "Project identifier used for resource naming and tagging"
  type        = string
  default     = "yieldswarm"
}

variable "environment" {
  description = "Deployment environment: dev | staging | prod"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

# ── Azure settings ────────────────────────────────────────────
variable "azure_location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus"
}

variable "azure_resource_group" {
  description = "Name of the existing Azure resource group to deploy into"
  type        = string
  default     = "yieldswarm-prod"
}

variable "azure_container_registry_sku" {
  description = "Azure Container Registry SKU (Basic | Standard | Premium)"
  type        = string
  default     = "Standard"
}

# ── DigitalOcean settings ─────────────────────────────────────
variable "do_region" {
  description = "Primary DigitalOcean region slug"
  type        = string
  default     = "nyc3"
}

variable "do_droplet_size" {
  description = "DigitalOcean Droplet size slug for agent nodes"
  type        = string
  default     = "s-2vcpu-4gb"
}

# ── Vultr settings ────────────────────────────────────────────
variable "vultr_region" {
  description = "Vultr region ID (ewr = New Jersey, sea = Seattle, etc.)"
  type        = string
  default     = "ewr"
}

variable "vultr_plan" {
  description = "Vultr VPS plan slug for agent nodes"
  type        = string
  default     = "vc2-2c-4gb"
}

# ── RunPod settings ───────────────────────────────────────────
variable "runpod_gpu_type" {
  description = "RunPod GPU type for GPU-accelerated agent shards"
  type        = string
  default     = "NVIDIA RTX A4000"
}

variable "runpod_pod_count" {
  description = "Number of RunPod GPU pods to provision"
  type        = number
  default     = 1
}

# ── Agent swarm settings ──────────────────────────────────────
variable "agent_count_total" {
  description = "Total number of AI agents in the swarm"
  type        = number
  default     = 10080
}

variable "agents_per_shard" {
  description = "Agents per cron shard"
  type        = number
  default     = 84
}

variable "cron_shard_count" {
  description = "Total number of cron shards"
  type        = number
  default     = 120
}
