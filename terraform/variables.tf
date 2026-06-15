variable "vault_addr" {
  description = "Vault API address (also set VAULT_ADDR for the Vault provider)."
  type        = string
}

variable "vault_skip_tls_verify" {
  description = "Skip TLS verification (dev only — never in production)."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment tag."
  type        = string
  default     = "production"
}

variable "azure_location" {
  description = "Azure region for resources."
  type        = string
  default     = "eastus2"
}

variable "azure_resource_group_name" {
  description = "Azure resource group name."
  type        = string
  default     = "yieldswarm-agents"
}

variable "do_region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "nyc3"
}

variable "vultr_region" {
  description = "Vultr region ID."
  type        = string
  default     = "ewr"
}

variable "runpod_gpu_type" {
  description = "RunPod GPU type for agent workloads."
  type        = string
  default     = "NVIDIA GeForce RTX 4090"
}
