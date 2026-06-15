variable "vault_addr" {
  description = "Vault API address (for example: https://vault.example.com)"
  type        = string
}

variable "vault_kv_mount" {
  description = "Vault KV v2 mount used for cloud and RPC secrets."
  type        = string
  default     = "kv"
}

variable "vault_secret_base_path" {
  description = "Base path under the KV mount for provider secret documents."
  type        = string
  default     = "infra/providers"
}

variable "environment" {
  description = "Environment segment used in Vault secret paths."
  type        = string
  default     = "prod"
}
