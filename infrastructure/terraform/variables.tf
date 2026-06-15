variable "vault_address" {
  description = "Vault API address, for example https://vault.example.com:8200"
  type        = string
}

variable "vault_token" {
  description = "Short-lived Vault token used by Terraform."
  type        = string
  sensitive   = true
}

variable "vault_infra_mount" {
  description = "kv-v2 mount containing infrastructure provider credentials."
  type        = string
  default     = "kv-infra"
}
