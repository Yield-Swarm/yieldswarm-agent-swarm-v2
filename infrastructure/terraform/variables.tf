variable "vault_address" {
  description = "Fully qualified Vault address, e.g. https://vault.internal:8200. Read from VAULT_ADDR if unset."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Vault enterprise namespace (leave null for OSS)."
  type        = string
  default     = null
}

variable "vault_kv_mount" {
  description = "KV v2 mount point that holds YieldSwarm secrets."
  type        = string
  default     = "secret"
  validation {
    condition     = length(var.vault_kv_mount) > 0 && !strcontains(var.vault_kv_mount, "/")
    error_message = "vault_kv_mount must be a single path segment, e.g. 'secret'."
  }
}

variable "vault_secret_base" {
  description = "Logical prefix under the KV mount that contains all YieldSwarm paths."
  type        = string
  default     = "yieldswarm"
}

variable "vault_auth_role_id" {
  description = "AppRole role_id for the terraform-deployer role. Safe to commit to CI config; not a secret on its own."
  type        = string
  default     = null
}

variable "vault_auth_secret_id" {
  description = "AppRole secret_id (or wrapping token if vault_auth_secret_id_is_wrapped=true). MUST come from a CI secret manager, never from tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "vault_approle_mount" {
  description = "Path the AppRole auth method is mounted at."
  type        = string
  default     = "approle"
}

variable "environment" {
  description = "Environment slug applied to all provisioned resources (dev|stage|prod)."
  type        = string
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "default_tags" {
  description = "Tags merged into every taggable resource."
  type        = map(string)
  default = {
    project    = "yieldswarm"
    managed_by = "terraform"
    component  = "agentswarm-os"
  }
}

# Per-provider toggles. Set false to skip a stack you don't deploy in a
# given environment - useful for tearing down spend.
variable "enable_azure" {
  type    = bool
  default = true
}

variable "enable_runpod" {
  type    = bool
  default = true
}

variable "enable_vultr" {
  type    = bool
  default = true
}

variable "enable_digitalocean" {
  type    = bool
  default = true
}
