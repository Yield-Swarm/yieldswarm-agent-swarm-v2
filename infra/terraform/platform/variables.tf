variable "vault_addr" {
  description = "Vault HTTP(S) address."
  type        = string
}

variable "vault_token" {
  description = "Vault token used by Terraform to read secrets."
  type        = string
  sensitive   = true
}

variable "vault_namespace" {
  description = "Optional Vault namespace (Enterprise/HCP Vault)."
  type        = string
  default     = null
}

variable "vault_kv_mount_path" {
  description = "KVv2 mount path where cloud provider and RPC secrets are stored."
  type        = string
  default     = "kv"
}

variable "azure_secret_path" {
  description = "KV path (without /data/) containing Azure credentials."
  type        = string
  default     = "platform/azure"
}

variable "runpod_secret_path" {
  description = "KV path (without /data/) containing RunPod credentials."
  type        = string
  default     = "platform/runpod"
}

variable "vultr_secret_path" {
  description = "KV path (without /data/) containing Vultr credentials."
  type        = string
  default     = "platform/vultr"
}

variable "digitalocean_secret_path" {
  description = "KV path (without /data/) containing DigitalOcean credentials."
  type        = string
  default     = "platform/digitalocean"
}

variable "rpc_secret_path" {
  description = "KV path (without /data/) containing RPC endpoint credentials."
  type        = string
  default     = "platform/rpc"
}
