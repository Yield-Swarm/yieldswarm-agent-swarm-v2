variable "vault_kv_mount" {
  description = "Vault KV v2 mount containing provider and RPC secrets."
  type        = string
  default     = "secret"
}

variable "vault_secret_paths" {
  description = "Vault KV v2 logical paths, without the mount prefix."
  type = object({
    azure        = string
    runpod       = string
    vultr        = string
    digitalocean = string
    rpc          = string
  })
  default = {
    azure        = "cloud/azure"
    runpod       = "cloud/runpod"
    vultr        = "cloud/vultr"
    digitalocean = "cloud/digitalocean"
    rpc          = "rpc/mainnet"
  }
}

variable "azure_environment" {
  description = "Azure cloud environment name used by the AzureRM provider."
  type        = string
  default     = "public"
}
