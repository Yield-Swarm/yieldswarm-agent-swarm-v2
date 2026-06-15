variable "vault_address" {
  description = "URL of the Vault cluster (e.g. https://vault.apn.internal:8200)."
  type        = string
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise namespace. Leave empty for OSS."
  type        = string
  default     = ""
}

variable "vault_kv_mount" {
  description = "Mount path of the KV v2 engine that holds APN secrets."
  type        = string
  default     = "kv"
}

variable "vault_secret_prefix" {
  description = "Logical prefix under the KV mount for APN secrets."
  type        = string
  default     = "apn"
}

variable "environment" {
  description = "Deployment environment tag (prod, staging, dev)."
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

# AppRole credentials for the vault provider. Populate these via the
# TF_VAR_vault_role_id / TF_VAR_vault_secret_id environment variables in
# CI (sourced from files staged at /run/apn/terraform.{role-id,secret-id}
# by the CI runner). They MUST NOT be set in any tfvars file.
variable "vault_role_id" {
  description = "AppRole role_id for the apn-terraform role."
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole secret_id for the apn-terraform role."
  type        = string
  sensitive   = true
}
