variable "vault_address" {
  description = "Address of the Vault server (e.g. https://vault.example.com:8200). Falls back to the VAULT_ADDR env var when empty."
  type        = string
  default     = ""
}

variable "vault_kv_mount" {
  description = "Mount path of the KV v2 secrets engine that holds the YieldSwarm secret tree."
  type        = string
  default     = "secret"
}

variable "vault_approle_path" {
  description = "Mount path of the AppRole auth method used by Terraform."
  type        = string
  default     = "approle"
}

variable "vault_role_id" {
  description = <<-EOT
    RoleID for the 'yieldswarm-terraform' AppRole. When set, Terraform logs in
    to Vault via AppRole. When empty, the provider falls back to VAULT_TOKEN
    from the environment (useful for local development).
  EOT
  type        = string
  default     = ""
}

variable "vault_secret_id" {
  description = "SecretID for the 'yieldswarm-terraform' AppRole. Supply via TF_VAR_vault_secret_id; never commit it."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_skip_child_token" {
  description = "Skip creating a child token. Set true when the AppRole token is single-use or has limited uses."
  type        = bool
  default     = true
}
