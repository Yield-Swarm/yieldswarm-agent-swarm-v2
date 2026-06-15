variable "vault_kv_mount_path" {
  description = "Vault KV v2 mount containing provider and RPC secrets."
  type        = string
  default     = "secret"
}

variable "azure_secret_path" {
  description = "KV v2 secret name for Azure service principal credentials."
  type        = string
  default     = "azure"
}

variable "runpod_secret_path" {
  description = "KV v2 secret name for RunPod credentials."
  type        = string
  default     = "runpod"
}

variable "vultr_secret_path" {
  description = "KV v2 secret name for Vultr credentials."
  type        = string
  default     = "vultr"
}

variable "digitalocean_secret_path" {
  description = "KV v2 secret name for DigitalOcean credentials."
  type        = string
  default     = "digitalocean"
}

variable "rpc_secret_path" {
  description = "KV v2 secret name for blockchain RPC endpoints and API keys."
  type        = string
  default     = "rpc"
}
