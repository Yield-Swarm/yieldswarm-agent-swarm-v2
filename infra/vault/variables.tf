variable "vault_addr" {
  description = "HTTPS address for the Vault cluster. Can also be set via VAULT_ADDR."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace, if used."
  type        = string
  default     = null
}

variable "vault_ca_cert_file" {
  description = "PEM bundle used to validate the Vault server certificate."
  type        = string
  default     = null
}

variable "vault_skip_tls_verify" {
  description = "Set to true only for local bootstrap or break-glass scenarios."
  type        = bool
  default     = false
}

variable "enable_secret_contract_validation" {
  description = "When true, Terraform will read Azure, RunPod, Vultr, DigitalOcean, and RPC secrets from Vault and verify that all required fields exist."
  type        = bool
  default     = false
}

variable "terraform_token_bound_cidrs" {
  description = "Optional CIDR allow-list for Terraform AppRole tokens."
  type        = list(string)
  default     = []
}

variable "akash_token_bound_cidrs" {
  description = "Optional CIDR allow-list for Akash runtime AppRole tokens."
  type        = list(string)
  default     = []
}
