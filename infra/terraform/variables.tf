variable "vault_addr" {
  description = "Vault API address used by Terraform."
  type        = string
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace (optional)."
  type        = string
  default     = null
}

variable "vault_cloud_mount" {
  description = "KV v2 mount that stores cloud credentials."
  type        = string
  default     = "cloud-secrets"
}
