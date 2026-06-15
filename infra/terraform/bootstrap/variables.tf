variable "application_name" {
  description = "Application identifier used in Vault secret paths."
  type        = string
  default     = "agentswarm"
}

variable "environment" {
  description = "Deployment environment stored under the Vault KV mounts."
  type        = string
  default     = "prod"
}

variable "platform_mount_path" {
  description = "KV v2 mount that stores cloud provider and RPC credentials."
  type        = string
  default     = "platform"
}

variable "runtime_mount_path" {
  description = "KV v2 mount that stores runtime application secrets."
  type        = string
  default     = "apps"
}

variable "approle_path" {
  description = "Vault auth path used for AppRole logins."
  type        = string
  default     = "approle"
}

variable "terraform_role_name" {
  description = "Name of the AppRole used by Terraform to read provider credentials."
  type        = string
  default     = "terraform"
}

variable "akash_role_name" {
  description = "Name of the AppRole used by the Akash workload at runtime."
  type        = string
  default     = "akash-runtime"
}

variable "terraform_secret_id_num_uses" {
  description = "How many times a Terraform SecretID may be used before Vault revokes it."
  type        = number
  default     = 10
}

variable "terraform_secret_id_ttl" {
  description = "How long a Terraform SecretID remains valid."
  type        = string
  default     = "15m"
}

variable "terraform_token_ttl" {
  description = "TTL for Terraform login tokens."
  type        = string
  default     = "1h"
}

variable "terraform_token_max_ttl" {
  description = "Maximum TTL for Terraform login tokens."
  type        = string
  default     = "4h"
}

variable "terraform_secret_id_bound_cidrs" {
  description = "Optional CIDRs that may use the Terraform SecretID."
  type        = list(string)
  default     = []
}

variable "terraform_token_bound_cidrs" {
  description = "Optional CIDRs that may use the Terraform token after login."
  type        = list(string)
  default     = []
}

variable "akash_secret_id_num_uses" {
  description = "Akash deployments should use single-use wrapped SecretIDs."
  type        = number
  default     = 1
}

variable "akash_secret_id_ttl" {
  description = "How long an Akash SecretID remains valid before first use."
  type        = string
  default     = "5m"
}

variable "akash_token_ttl" {
  description = "TTL for Akash runtime tokens."
  type        = string
  default     = "15m"
}

variable "akash_token_max_ttl" {
  description = "Maximum TTL for Akash runtime tokens."
  type        = string
  default     = "1h"
}

variable "akash_secret_id_bound_cidrs" {
  description = "Optional CIDRs that may use the Akash SecretID."
  type        = list(string)
  default     = []
}

variable "akash_token_bound_cidrs" {
  description = "Optional CIDRs that may use the Akash runtime token after login."
  type        = list(string)
  default     = []
}
