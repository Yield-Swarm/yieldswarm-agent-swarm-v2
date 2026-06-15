variable "vault_addr" {
  description = "Vault HTTPS address."
  type        = string
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace. Leave null for OSS Vault."
  type        = string
  default     = null
}

variable "vault_approle_backend_path" {
  description = "AppRole auth mount path used by Terraform to authenticate to Vault."
  type        = string
  default     = "approle"
}

variable "vault_role_id" {
  description = "Vault AppRole RoleID used by Terraform."
  type        = string
}

variable "vault_secret_id" {
  description = "Vault AppRole SecretID used by Terraform."
  type        = string
  sensitive   = true
}

variable "vault_kv_mount_path" {
  description = "KV v2 mount path that stores provider and RPC secrets."
  type        = string
  default     = "kvv2"
}
