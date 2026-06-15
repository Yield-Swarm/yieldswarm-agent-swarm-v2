variable "vault_addr" {
  description = "HTTPS URL of the Vault cluster."
  type        = string
}

variable "vault_namespace" {
  description = "Vault Enterprise/HCP namespace. Leave empty for OSS Vault."
  type        = string
  default     = ""
}

variable "vault_skip_tls_verify" {
  description = "Set only for local throwaway development Vault instances."
  type        = bool
  default     = false
}

variable "kv_mount_path" {
  description = "KV v2 mount path used for YieldSwarm secrets."
  type        = string
  default     = "secret"
}

variable "azure_secret_path" {
  description = "KV v2 path containing Azure service principal credentials."
  type        = string
  default     = "yieldswarm/cloud/azure"
}

variable "runpod_secret_path" {
  description = "KV v2 path containing RunPod API credentials."
  type        = string
  default     = "yieldswarm/cloud/runpod"
}

variable "vultr_secret_path" {
  description = "KV v2 path containing Vultr API credentials."
  type        = string
  default     = "yieldswarm/cloud/vultr"
}

variable "digitalocean_secret_path" {
  description = "KV v2 path containing DigitalOcean API credentials."
  type        = string
  default     = "yieldswarm/cloud/digitalocean"
}

variable "rpc_secret_path" {
  description = "KV v2 path containing blockchain RPC endpoints and keys."
  type        = string
  default     = "yieldswarm/rpc"
}
