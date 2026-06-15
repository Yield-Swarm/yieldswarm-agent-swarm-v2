# =============================================================================
# Input variables. None of these hold secret material — only Vault coordinates
# and feature toggles. Secret values are fetched from Vault at runtime.
# =============================================================================

variable "vault_address" {
  description = "Vault API address (or set VAULT_ADDR)."
  type        = string
  default     = null
}

variable "vault_kv_mount" {
  description = "Mount point of the KV v2 engine holding YieldSwarm secrets."
  type        = string
  default     = "kv"
}

variable "vault_namespace" {
  description = "Vault namespace (Vault Enterprise / HCP). Empty for OSS."
  type        = string
  default     = null
}

variable "vault_approle_role_id" {
  description = <<-EOT
    Role ID of the 'terraform-provisioner' AppRole. Supply via
    TF_VAR_vault_approle_role_id (CI) rather than tfvars — never commit it.
  EOT
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_approle_secret_id" {
  description = <<-EOT
    Secret ID for the 'terraform-provisioner' AppRole. Supply via
    TF_VAR_vault_approle_secret_id (CI). Short-TTL, single-use recommended.
  EOT
  type        = string
  default     = ""
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment label (e.g. prod, staging)."
  type        = string
  default     = "prod"
}

# --- Feature toggles --------------------------------------------------------
# Example resources are gated OFF by default so `terraform validate` and CI
# planning work without provisioning anything. Flip these on per environment.
variable "enable_azure_examples" {
  description = "Create the example Azure resource group."
  type        = bool
  default     = false
}

variable "enable_digitalocean_examples" {
  description = "Create the example DigitalOcean project."
  type        = bool
  default     = false
}

variable "enable_vultr_examples" {
  description = "Create the example Vultr SSH key."
  type        = bool
  default     = false
}

variable "azure_location" {
  description = "Azure region for example resources."
  type        = string
  default     = "eastus"
}
