variable "vault_addr" {
  description = "Vault cluster address. Prefer VAULT_ADDR in CI and shells."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace. Leave null for OSS Vault."
  type        = string
  default     = null
}

variable "vault_kv_mount" {
  description = "KV v2 mount that contains Terraform provider and RPC secrets."
  type        = string
  default     = "secret"
}

variable "azure_secret_path" {
  description = "KV v2 logical path for Azure provider credentials."
  type        = string
  default     = "terraform/azure"
}

variable "digitalocean_secret_path" {
  description = "KV v2 logical path for DigitalOcean provider credentials."
  type        = string
  default     = "terraform/digitalocean"
}

variable "runpod_secret_path" {
  description = "KV v2 logical path for RunPod credentials consumed by modules or external data sources."
  type        = string
  default     = "terraform/runpod"
}

variable "vultr_secret_path" {
  description = "KV v2 logical path for Vultr provider credentials."
  type        = string
  default     = "terraform/vultr"
}

variable "rpc_secret_path" {
  description = "KV v2 logical path for blockchain RPC credentials and URLs."
  type        = string
  default     = "terraform/rpc"
}
