variable "vault_addr" {
  description = "Vault API address. If null, the Vault provider reads VAULT_ADDR."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise namespace. If null, VAULT_NAMESPACE or the root namespace is used."
  type        = string
  default     = null
}

variable "kv_mount_path" {
  description = "KV v2 mount path that stores YieldSwarm runtime and Terraform secrets."
  type        = string
  default     = "yieldswarm"

  validation {
    condition     = length(trim(var.kv_mount_path, "/")) > 0
    error_message = "kv_mount_path must not be empty."
  }
}

variable "approle_auth_path" {
  description = "AppRole auth backend path used by Akash runtime workloads."
  type        = string
  default     = "approle"

  validation {
    condition     = length(trim(var.approle_auth_path, "/")) > 0
    error_message = "approle_auth_path must not be empty."
  }
}

variable "terraform_policy_name" {
  description = "Vault policy name for Terraform secret reads."
  type        = string
  default     = "yieldswarm-terraform-read"
}

variable "akash_policy_name" {
  description = "Vault policy name for Akash runtime secret reads."
  type        = string
  default     = "yieldswarm-akash-runtime"
}

variable "secret_operator_policy_name" {
  description = "Vault policy name for operators allowed to write YieldSwarm secrets."
  type        = string
  default     = "yieldswarm-secret-operator"
}

variable "akash_role_name" {
  description = "AppRole role name used by Akash deployments."
  type        = string
  default     = "yieldswarm-akash-runtime"
}

variable "akash_token_ttl_seconds" {
  description = "Vault token TTL issued to Akash workloads."
  type        = number
  default     = 3600

  validation {
    condition     = var.akash_token_ttl_seconds > 0
    error_message = "akash_token_ttl_seconds must be greater than zero."
  }
}

variable "akash_token_max_ttl_seconds" {
  description = "Maximum Vault token TTL issued to Akash workloads."
  type        = number
  default     = 14400

  validation {
    condition     = var.akash_token_max_ttl_seconds > 0
    error_message = "akash_token_max_ttl_seconds must be greater than zero."
  }
}

variable "akash_secret_id_ttl_seconds" {
  description = "TTL for generated AppRole secret IDs. Keep short because the Akash deploy flow uses response wrapping."
  type        = number
  default     = 600

  validation {
    condition     = var.akash_secret_id_ttl_seconds > 0
    error_message = "akash_secret_id_ttl_seconds must be greater than zero."
  }
}

variable "akash_secret_id_num_uses" {
  description = "Number of times an Akash AppRole secret ID may be used."
  type        = number
  default     = 1

  validation {
    condition     = var.akash_secret_id_num_uses > 0
    error_message = "akash_secret_id_num_uses must be greater than zero."
  }
}
