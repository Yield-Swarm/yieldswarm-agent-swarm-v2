variable "vault_address" {
  description = "HTTPS address for the Vault cluster."
  type        = string
}

variable "vault_namespace" {
  description = "Optional Vault namespace for enterprise deployments."
  type        = string
  default     = null
  nullable    = true
}

variable "vault_ca_cert_file" {
  description = "Optional CA bundle file path used to verify the Vault TLS certificate."
  type        = string
  default     = null
  nullable    = true
}

variable "vault_skip_tls_verify" {
  description = "Set to true only for non-production testing."
  type        = bool
  default     = false
}

variable "vault_token" {
  description = "Operator token used to bootstrap mounts, policies, and AppRoles."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "kv_mount_path" {
  description = "KV v2 mount path for platform and runtime secrets."
  type        = string
  default     = "kv"
}

variable "transit_mount_path" {
  description = "Transit secrets engine mount path."
  type        = string
  default     = "transit"
}

variable "approle_mount_path" {
  description = "AppRole auth mount path."
  type        = string
  default     = "approle"
}

variable "provider_secret_paths" {
  description = "KV v2 secret paths read by Terraform provider configurations."
  type = object({
    azure        = string
    runpod       = string
    vultr        = string
    digitalocean = string
  })
  default = {
    azure        = "platform/providers/azure"
    runpod       = "platform/providers/runpod"
    vultr        = "platform/providers/vultr"
    digitalocean = "platform/providers/digitalocean"
  }
}

variable "rpc_secret_path" {
  description = "KV v2 secret path containing primary and failover RPC endpoints."
  type        = string
  default     = "platform/rpc/mainnet"
}

variable "akash_runtime_secret_path" {
  description = "KV v2 secret path containing runtime environment variables for the Akash workload."
  type        = string
  default     = "runtime/akash"
}

variable "terraform_policy_name" {
  description = "Vault policy name for Terraform automation."
  type        = string
  default     = "terraform-platform"
}

variable "akash_policy_name" {
  description = "Vault policy name for the Akash runtime."
  type        = string
  default     = "akash-runtime"
}

variable "terraform_role_name" {
  description = "AppRole name used by Terraform runs."
  type        = string
  default     = "terraform-platform"
}

variable "akash_role_name" {
  description = "AppRole name used by the Akash runtime."
  type        = string
  default     = "akash-runtime"
}

variable "terraform_token_ttl_seconds" {
  description = "Default TTL for Terraform-issued Vault tokens."
  type        = number
  default     = 3600
}

variable "terraform_token_max_ttl_seconds" {
  description = "Maximum TTL for Terraform-issued Vault tokens."
  type        = number
  default     = 14400
}

variable "terraform_secret_id_ttl_seconds" {
  description = "Lifetime of Terraform AppRole SecretIDs."
  type        = number
  default     = 86400
}

variable "terraform_secret_id_num_uses" {
  description = "Maximum number of times a Terraform SecretID may be used."
  type        = number
  default     = 10
}

variable "terraform_token_bound_cidrs" {
  description = "Optional CIDR allow-list for Terraform-issued Vault tokens."
  type        = list(string)
  default     = []
}

variable "terraform_secret_id_bound_cidrs" {
  description = "Optional CIDR allow-list for Terraform SecretIDs."
  type        = list(string)
  default     = []
}

variable "akash_token_ttl_seconds" {
  description = "Default TTL for Akash runtime Vault tokens."
  type        = number
  default     = 900
}

variable "akash_token_max_ttl_seconds" {
  description = "Maximum TTL for Akash runtime Vault tokens."
  type        = number
  default     = 3600
}

variable "akash_secret_id_ttl_seconds" {
  description = "Lifetime of Akash AppRole SecretIDs."
  type        = number
  default     = 900
}

variable "akash_secret_id_num_uses" {
  description = "Maximum number of times an Akash SecretID may be used."
  type        = number
  default     = 1
}

variable "akash_token_bound_cidrs" {
  description = "Optional CIDR allow-list for Akash runtime Vault tokens."
  type        = list(string)
  default     = []
}

variable "akash_secret_id_bound_cidrs" {
  description = "Optional CIDR allow-list for Akash runtime SecretIDs."
  type        = list(string)
  default     = []
}
