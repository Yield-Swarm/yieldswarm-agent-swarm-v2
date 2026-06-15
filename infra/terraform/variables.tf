variable "vault_addr" {
  description = "Vault HTTPS address."
  type        = string
}

variable "vault_token" {
  description = "Vault token used by Terraform to read secrets. Use short-lived AppRole login tokens."
  type        = string
  sensitive   = true
}

variable "vault_namespace" {
  description = "Optional Vault enterprise namespace."
  type        = string
  default     = ""
}

variable "vault_cloud_mount" {
  description = "Vault kv-v2 mount containing cloud provider credentials."
  type        = string
  default     = "cloud"
}

variable "vault_rpc_mount" {
  description = "Vault kv-v2 mount containing RPC credentials."
  type        = string
  default     = "rpc"
}

variable "azure_secret_name" {
  description = "Vault secret name (path within mount) for Azure credentials."
  type        = string
  default     = "azure"
}

variable "runpod_secret_name" {
  description = "Vault secret name for RunPod credentials."
  type        = string
  default     = "runpod"
}

variable "vultr_secret_name" {
  description = "Vault secret name for Vultr credentials."
  type        = string
  default     = "vultr"
}

variable "digitalocean_secret_name" {
  description = "Vault secret name for DigitalOcean credentials."
  type        = string
  default     = "digitalocean"
}

variable "rpc_secret_name" {
  description = "Vault secret name for shared RPC configuration."
  type        = string
  default     = "default"
}
