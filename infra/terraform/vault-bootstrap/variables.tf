variable "vault_addr" {
  description = "HTTPS URL of the Vault cluster."
  type        = string
}

variable "vault_namespace" {
  description = "Vault Enterprise/HCP namespace. Leave empty for OSS Vault."
  type        = string
  default     = ""
}

variable "vault_skip_tls_verify" {
  description = "Set only for local throwaway development Vault instances."
  type        = bool
  default     = false
}

variable "kv_mount_path" {
  description = "KV v2 mount path used for YieldSwarm secrets."
  type        = string
  default     = "secret"
}

variable "transit_mount_path" {
  description = "Transit mount path used for envelope encryption keys."
  type        = string
  default     = "transit"
}

variable "policy_prefix" {
  description = "Prefix applied to Vault policy names."
  type        = string
  default     = "yieldswarm"
}

variable "approle_mount_path" {
  description = "AppRole auth mount path."
  type        = string
  default     = "approle"
}

variable "runtime_token_ttl" {
  description = "Default runtime AppRole token TTL."
  type        = string
  default     = "1h"
}

variable "runtime_token_max_ttl" {
  description = "Maximum runtime AppRole token TTL."
  type        = string
  default     = "4h"
}

variable "terraform_token_ttl" {
  description = "Terraform CI AppRole token TTL."
  type        = string
  default     = "30m"
}

variable "terraform_token_max_ttl" {
  description = "Maximum Terraform CI AppRole token TTL."
  type        = string
  default     = "2h"
}
