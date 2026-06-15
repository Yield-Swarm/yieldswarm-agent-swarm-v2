variable "vault_address" {
  description = "Vault server address. Defaults to the VAULT_ADDR env var when empty."
  type        = string
  default     = ""
}

variable "vault_kv_mount" {
  description = "KVv2 mount path on Vault that holds YieldSwarm secrets."
  type        = string
  default     = "yieldswarm"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev | staging | prod."
  }
}

variable "azure_location" {
  description = "Azure region for VMs / App Services."
  type        = string
  default     = "eastus"
}

variable "do_region" {
  description = "DigitalOcean region for Droplets / Spaces."
  type        = string
  default     = "nyc3"
}

variable "vultr_region" {
  description = "Vultr region for instances."
  type        = string
  default     = "ewr"
}

variable "runpod_endpoint" {
  description = "RunPod REST endpoint."
  type        = string
  default     = "https://api.runpod.io/graphql"
}

variable "agent_shard_count" {
  description = "Number of agent shards to provision per cloud."
  type        = number
  default     = 1
}
