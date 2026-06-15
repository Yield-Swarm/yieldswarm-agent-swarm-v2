# =============================================================================
# Input Variables
# YieldSwarm AgentSwarm OS v2.0
# =============================================================================

variable "vault_addr" {
  description = "Vault server address (e.g. https://vault.yieldswarm.internal:8200)"
  type        = string
}

variable "vault_environment" {
  description = "Environment namespace used in Vault secret paths (production | staging | dev)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "dev"], var.vault_environment)
    error_message = "vault_environment must be one of: production, staging, dev"
  }
}

variable "azure_location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus"
}

variable "azure_resource_group" {
  description = "Azure resource group for AgentSwarm resources"
  type        = string
  default     = "yieldswarm-agents-rg"
}

variable "do_region" {
  description = "DigitalOcean region slug"
  type        = string
  default     = "nyc3"
}

variable "vultr_region" {
  description = "Vultr region ID"
  type        = string
  default     = "ewr"
}

variable "runpod_gpu_type" {
  description = "RunPod GPU type for inference workloads"
  type        = string
  default     = "NVIDIA RTX A4000"
}

variable "runpod_gpu_count" {
  description = "Number of RunPod GPU instances"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project     = "yieldswarm"
    managed_by  = "terraform"
    secrets_src = "vault"
  }
}
