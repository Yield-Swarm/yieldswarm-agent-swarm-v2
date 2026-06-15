variable "vault_address" {
  description = "Vault API address. Override via TF_VAR_vault_address or CI env."
  type        = string
  default     = null
}

variable "vault_role_id" {
  description = "AppRole role_id for yieldswarm-terraform. Set via TF_VAR_vault_role_id."
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole secret_id for yieldswarm-terraform. Set via TF_VAR_vault_secret_id."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment label (dev, staging, prod)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "azure_resource_group_name" {
  description = "Override Azure resource group name; defaults to Vault value."
  type        = string
  default     = null
}

variable "azure_location" {
  description = "Override Azure region; defaults to Vault value."
  type        = string
  default     = null
}
