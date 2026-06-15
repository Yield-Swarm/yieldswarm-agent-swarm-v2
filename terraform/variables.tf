variable "vault_addr" {
  description = "Address of the Vault server, e.g. https://vault.yieldswarm.internal:8200."
  type        = string

  validation {
    condition     = can(regex("^https?://", var.vault_addr))
    error_message = "vault_addr must be an http(s) URL."
  }
}

variable "vault_role_id" {
  description = "AppRole role_id for the 'terraform' (or 'ci') role. Non-secret on its own."
  type        = string
}

variable "vault_secret_id" {
  description = <<-EOT
    Unwrapped AppRole secret_id. Pass via TF_VAR_vault_secret_id only — never
    put this in a checked-in *.tfvars file. CI obtains it by unwrapping the
    one-shot wrap token from vault/scripts/issue-secret-id.sh.
  EOT
  type        = string
  sensitive   = true
}

variable "kv_mount" {
  description = "KV v2 mount where YieldSwarm secrets live."
  type        = string
  default     = "yieldswarm"
}

variable "rpc_chains" {
  description = "RPC chains to fetch and validate."
  type        = list(string)
  default     = ["solana", "ethereum", "ton", "bittensor"]
}

variable "required_rpc_chains" {
  description = "Subset of rpc_chains that MUST be present and non-empty."
  type        = list(string)
  default     = ["solana"]
}

variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "azure_resource_group_name" {
  type    = string
  default = "yieldswarm-prod-rg"
}

variable "digitalocean_default_region" {
  type    = string
  default = "nyc3"
}

variable "verify_runpod_api_key" {
  description = "If true, plan-time live call to RunPod to verify the API key."
  type        = bool
  default     = true
}

variable "enable_azure" {
  type    = bool
  default = true
}

variable "enable_runpod" {
  type    = bool
  default = true
}

variable "enable_vultr" {
  type    = bool
  default = true
}

variable "enable_digitalocean" {
  type    = bool
  default = true
}
