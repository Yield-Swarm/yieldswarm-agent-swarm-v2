variable "kv_mount_path" {
  description = "Vault KV v2 mount used for platform, provider, RPC, and Akash runtime secrets."
  type        = string
  default     = "secret"
}

variable "transit_mount_path" {
  description = "Vault transit mount used for runtime cryptographic helpers."
  type        = string
  default     = "transit"
}

variable "approle_mount_path" {
  description = "Vault AppRole auth mount used by Terraform automation and Akash runtime workloads."
  type        = string
  default     = "approle"
}

variable "terraform_token_bound_cidrs" {
  description = "Optional CIDR allow-list for Terraform AppRole tokens. Leave empty only for local bootstrap."
  type        = list(string)
  default     = []
}

variable "akash_token_bound_cidrs" {
  description = "Optional CIDR allow-list for Akash AppRole tokens. Populate with trusted provider egress CIDRs where possible."
  type        = list(string)
  default     = []
}
