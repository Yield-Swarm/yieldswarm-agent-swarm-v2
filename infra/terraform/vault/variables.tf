variable "vault_addr" {
  description = "Vault API address used by the Terraform Vault provider."
  type        = string
}

variable "vault_token" {
  description = "Vault token with enough rights to create mounts, policies, and auth roles."
  type        = string
  sensitive   = true
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise namespace. Leave null for the root namespace."
  type        = string
  default     = null
  nullable    = true
}

variable "kv_platform_mount_path" {
  description = "Mount path for platform/provider credentials."
  type        = string
  default     = "kv-platform"
}

variable "kv_runtime_mount_path" {
  description = "Mount path for runtime/application secrets."
  type        = string
  default     = "kv-runtime"
}

variable "transit_mount_path" {
  description = "Mount path for the Vault transit engine."
  type        = string
  default     = "transit"
}

variable "approle_path" {
  description = "Auth path for the AppRole auth backend."
  type        = string
  default     = "approle"
}

variable "enable_secret_reads" {
  description = "When true, Terraform reads and validates provider secrets from Vault after they have been seeded."
  type        = bool
  default     = false
}

variable "kv_max_versions" {
  description = "How many versions each KV v2 secret should retain."
  type        = number
  default     = 10
}

variable "kv_delete_version_after_seconds" {
  description = "How long old KV v2 secret versions remain recoverable before Vault deletes them."
  type        = number
  default     = 2592000
}

variable "akash_role_name" {
  description = "Vault AppRole name used by Akash workloads."
  type        = string
  default     = "akash-runtime"
}

variable "akash_token_ttl_seconds" {
  description = "Default TTL for tokens minted via the Akash AppRole."
  type        = number
  default     = 3600
}

variable "akash_token_max_ttl_seconds" {
  description = "Maximum TTL for tokens minted via the Akash AppRole."
  type        = number
  default     = 14400
}

variable "akash_secret_id_ttl_seconds" {
  description = "TTL for AppRole SecretIDs issued to Akash workloads."
  type        = number
  default     = 86400
}

variable "akash_secret_id_num_uses" {
  description = "Maximum number of times each Akash SecretID can be exchanged for a token."
  type        = number
  default     = 10
}

variable "akash_secret_id_bound_cidrs" {
  description = "Optional CIDR allowlist for SecretIDs issued to the Akash AppRole."
  type        = list(string)
  default     = []
}
