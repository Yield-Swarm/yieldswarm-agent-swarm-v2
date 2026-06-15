variable "vault_addr" {
  description = "HashiCorp Vault API address"
  type        = string
}

variable "vault_role_id" {
  description = "AppRole role_id for yieldswarm-terraform (from Vault bootstrap)"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole secret_id — inject via TF_VAR_vault_secret_id or CI secret store"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment (prod, staging)"
  type        = string
  default     = "prod"
}

variable "azure_resource_group_name" {
  description = "Azure resource group (overrides Vault secret if set)"
  type        = string
  default     = ""
}

variable "azure_location" {
  description = "Azure region (overrides Vault secret if set)"
  type        = string
  default     = ""
}

variable "do_region" {
  description = "DigitalOcean region for droplets"
  type        = string
  default     = "nyc3"
}

variable "vultr_region" {
  description = "Vultr region for compute"
  type        = string
  default     = "ewr"
}

variable "runpod_gpu_type" {
  description = "RunPod GPU type identifier"
  type        = string
  default     = "NVIDIA RTX 4090"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    project     = "yieldswarm"
    managed_by  = "terraform"
    environment = "prod"
  }
}
