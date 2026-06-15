variable "environment" {
  description = "Deployment environment (prod, staging, dev).  Selects the Vault KV namespace."
  type        = string
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "vault_address" {
  description = "Vault cluster API endpoint.  HTTPS required in prod."
  type        = string
  validation {
    condition     = can(regex("^https?://", var.vault_address))
    error_message = "vault_address must be a URL."
  }
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace (optional)."
  type        = string
  default     = null
}

variable "vault_kv_mount" {
  description = "Mount path of the KV v2 engine inside Vault."
  type        = string
  default     = "kv"
}

variable "vault_skip_tls_verify" {
  description = "Disable TLS verification - dev only."
  type        = bool
  default     = false
}

# AppRole auth.  These two values are the ONLY long-lived terraform secrets and
# they live in the CI runner's environment.  Everything else is fetched from
# Vault at plan/apply time via `data "vault_kv_secret_v2"`.
variable "vault_role_id" {
  description = "AppRole role_id for the terraform-cicd role.  Provided via VAULT_ROLE_ID env var in CI."
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "Wrapped or unwrapped AppRole secret_id.  If wrapped, provide via VAULT_SECRET_ID_WRAPPED instead."
  type        = string
  sensitive   = true
  default     = null
}

variable "vault_secret_id_wrapped" {
  description = "Response-wrapped secret_id token (single-use).  Preferred over vault_secret_id."
  type        = string
  sensitive   = true
  default     = null
}

# Which clouds to provision in this run.  Lets a single root module target a
# subset of providers without forcing all credentials to be present.
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

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    project = "yieldswarm"
    owner   = "platform"
    managed = "terraform"
  }
}
