variable "vault_address" {
  description = "Vault API address. Set via TF_VAR_vault_address or VAULT_ADDR in the shell running Terraform."
  type        = string
  default     = "https://vault.yieldswarm.internal:8200"
}

variable "vault_skip_tls_verify" {
  description = "Skip TLS verification for Vault (dev only)."
  type        = bool
  default     = false
}

variable "vault_approle_role_id" {
  description = "AppRole role_id for Terraform. Set via TF_VAR or CI secret."
  type        = string
  sensitive   = true
}

variable "vault_approle_secret_id" {
  description = "AppRole secret_id for Terraform. Set via TF_VAR or CI secret."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Resource naming prefix."
  type        = string
  default     = "yieldswarm"
}

variable "azure_create_resource_group" {
  description = "Whether Terraform should create the Azure resource group."
  type        = bool
  default     = false
}

variable "do_create_droplet" {
  description = "Whether to provision a DigitalOcean droplet (set false for secrets-only validation)."
  type        = bool
  default     = false
}

variable "vultr_create_instance" {
  description = "Whether to provision a Vultr instance (set false for secrets-only validation)."
  type        = bool
  default     = false
}

variable "runpod_create_pod" {
  description = "Whether to provision a RunPod GPU pod (set false for secrets-only validation)."
  type        = bool
  default     = false
}
