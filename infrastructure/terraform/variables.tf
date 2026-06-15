variable "vault_address" {
  description = "Vault cluster address (e.g. https://vault.example.com:8200)."
  type        = string
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace, empty for OSS."
  type        = string
  default     = ""
}

variable "vault_role_id" {
  description = "AppRole role_id for the yieldswarm-terraform role."
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = <<-EOT
    AppRole secret_id for the yieldswarm-terraform role.
    Pass via -var, TF_VAR_vault_secret_id, or `vault unwrap`. Never commit.
  EOT
  type        = string
  sensitive   = true
}

variable "vault_kv_mount" {
  description = "Mount path of the KV v2 engine that holds the secrets."
  type        = string
  default     = "kv"
}

variable "vault_secret_root" {
  description = "Top-level path under the KV mount for this stack."
  type        = string
  default     = "yieldswarm"
}

variable "environment" {
  description = "Deployment environment label (prod, staging, dev)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of prod, staging, dev."
  }
}

variable "enabled_clouds" {
  description = "Which clouds to provision against. Disable any not needed."
  type = object({
    azure        = bool
    runpod       = bool
    vultr        = bool
    digitalocean = bool
  })
  default = {
    azure        = true
    runpod       = true
    vultr        = true
    digitalocean = true
  }
}
