variable "vault_addr" {
  description = "Vault API address. If null, the Vault provider reads VAULT_ADDR."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise namespace. If null, VAULT_NAMESPACE or the root namespace is used."
  type        = string
  default     = null
}

variable "vault_kv_mount" {
  description = "KV v2 mount that contains cloud and RPC secrets."
  type        = string
  default     = "yieldswarm"

  validation {
    condition     = length(trim(var.vault_kv_mount, "/")) > 0
    error_message = "vault_kv_mount must not be empty."
  }
}

variable "azure_secret_name" {
  description = "KV v2 secret name for Azure credentials."
  type        = string
  default     = "cloud/azure"
}

variable "runpod_secret_name" {
  description = "KV v2 secret name for RunPod credentials."
  type        = string
  default     = "cloud/runpod"
}

variable "vultr_secret_name" {
  description = "KV v2 secret name for Vultr credentials."
  type        = string
  default     = "cloud/vultr"
}

variable "digitalocean_secret_name" {
  description = "KV v2 secret name for DigitalOcean credentials."
  type        = string
  default     = "cloud/digitalocean"
}

variable "rpc_secret_name" {
  description = "KV v2 secret name for blockchain RPC configuration."
  type        = string
  default     = "rpc"
}
