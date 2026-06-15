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

variable "vault_approle_mount_path" {
  description = "AppRole auth mount path used by Terraform automation."
  type        = string
  default     = "approle"
}

variable "vault_role_id" {
  description = "Vault AppRole role ID for Terraform automation."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "vault_secret_id" {
  description = "Vault AppRole secret ID for Terraform automation."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "vault_kv_mount" {
  description = "KV v2 mount path used for provider and RPC secrets."
  type        = string
  default     = "kv"
}

variable "vault_secret_paths" {
  description = "KV v2 secret paths read by Terraform."
  type = object({
    azure        = string
    runpod       = string
    vultr        = string
    digitalocean = string
    rpc          = string
  })
  default = {
    azure        = "platform/providers/azure"
    runpod       = "platform/providers/runpod"
    vultr        = "platform/providers/vultr"
    digitalocean = "platform/providers/digitalocean"
    rpc          = "platform/rpc/mainnet"
  }
}

variable "azurerm_resource_provider_registrations" {
  description = "AzureRM provider registration mode. Use none for least-privilege service principals."
  type        = string
  default     = "none"
}
