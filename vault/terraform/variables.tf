variable "vault_addr" {
  description = "Address of the Vault server (e.g. https://vault.yieldswarm.io:8200)."
  type        = string
  default     = ""
}

variable "vault_admin_role_id" {
  description = "AppRole role_id for the admin role (used if not relying on VAULT_TOKEN)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_admin_secret_id" {
  description = "AppRole secret_id for the admin role."
  type        = string
  default     = ""
  sensitive   = true
}

variable "terraform_token_ttl" {
  description = "Token TTL for the Terraform AppRole (e.g. '1h')."
  type        = string
  default     = "1h"
}

variable "terraform_token_max_ttl" {
  description = "Maximum token TTL for the Terraform AppRole."
  type        = string
  default     = "4h"
}

variable "akash_agent_token_ttl" {
  description = "Token TTL for the Akash Agent AppRole."
  type        = string
  default     = "2h"
}

variable "akash_agent_token_max_ttl" {
  description = "Maximum token TTL for the Akash Agent AppRole."
  type        = string
  default     = "8h"
}

variable "akash_agent_secret_id_ttl" {
  description = "TTL for Akash Agent secret_ids (0 = never expire)."
  type        = string
  default     = "24h"
}
