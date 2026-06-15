variable "kv_mount" {
  description = "Vault KV v2 mount used for application, cloud provider, and RPC secrets."
  type        = string
  default     = "secret"
}

variable "transit_mount" {
  description = "Vault transit mount used for deployment envelope encryption and signing keys."
  type        = string
  default     = "transit"
}

variable "transit_key_name" {
  description = "Name of the transit key reserved for Akash runtime secret material."
  type        = string
  default     = "agentswarm-akash-runtime"
}

variable "approle_mount" {
  description = "Vault AppRole auth mount used by Terraform automation and Akash runtime workloads."
  type        = string
  default     = "approle"
}

variable "policy_prefix" {
  description = "Prefix for Vault policies and AppRole role names."
  type        = string
  default     = "agentswarm"
}

variable "akash_token_ttl" {
  description = "TTL for Vault tokens issued to Akash runtime workloads."
  type        = string
  default     = "1h"
}

variable "akash_token_max_ttl" {
  description = "Maximum TTL for Vault tokens issued to Akash runtime workloads."
  type        = string
  default     = "4h"
}

variable "terraform_token_ttl" {
  description = "TTL for Vault tokens issued to Terraform automation."
  type        = string
  default     = "30m"
}

variable "terraform_token_max_ttl" {
  description = "Maximum TTL for Vault tokens issued to Terraform automation."
  type        = string
  default     = "2h"
}

variable "token_bound_cidrs" {
  description = "Optional CIDR ranges allowed to use issued AppRole tokens. Leave empty until stable egress ranges are known."
  type        = list(string)
  default     = []
}
