variable "vault_namespace" {
  description = "Vault Enterprise namespace. Leave null for OSS Vault."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment label used in descriptions and metadata."
  type        = string
  default     = "prod"
}

variable "kv_mount_path" {
  description = "Path for the KV v2 mount that stores static provider and workload secrets."
  type        = string
  default     = "kvv2"
}

variable "transit_mount_path" {
  description = "Path for the transit engine used for application-side cryptography."
  type        = string
  default     = "transit"
}

variable "approle_path" {
  description = "Path for the AppRole auth backend."
  type        = string
  default     = "approle"
}

variable "terraform_role_name" {
  description = "AppRole name used by Terraform when reading provider credentials from Vault."
  type        = string
  default     = "yieldswarm-terraform"
}

variable "openclaw_role_name" {
  description = "AppRole name used by the OpenClaw runtime on Akash."
  type        = string
  default     = "openclaw-runtime"
}

variable "openclaw_secret_path" {
  description = "Relative KV v2 path that contains the OpenClaw runtime secret bundle."
  type        = string
  default     = "apps/openclaw/runtime"
}

variable "terraform_secret_id_ttl_seconds" {
  description = "TTL, in seconds, for Terraform SecretIDs."
  type        = number
  default     = 900
}

variable "terraform_token_ttl_seconds" {
  description = "TTL, in seconds, for Terraform Vault tokens."
  type        = number
  default     = 1800
}

variable "terraform_token_max_ttl_seconds" {
  description = "Maximum TTL, in seconds, for Terraform Vault tokens."
  type        = number
  default     = 3600
}

variable "openclaw_secret_id_ttl_seconds" {
  description = "TTL, in seconds, for OpenClaw SecretIDs."
  type        = number
  default     = 900
}

variable "openclaw_token_ttl_seconds" {
  description = "TTL, in seconds, for OpenClaw Vault tokens."
  type        = number
  default     = 3600
}

variable "openclaw_token_max_ttl_seconds" {
  description = "Maximum TTL, in seconds, for OpenClaw Vault tokens."
  type        = number
  default     = 14400
}

variable "openclaw_secret_id_bound_cidrs" {
  description = "Optional CIDRs allowed to use OpenClaw SecretIDs."
  type        = list(string)
  default     = []
}

variable "openclaw_token_bound_cidrs" {
  description = "Optional CIDRs that issued OpenClaw tokens are allowed to operate from."
  type        = list(string)
  default     = []
}
