# =============================================================================
# Root module variables.
#
# NOTE: This module deliberately does NOT take any provider credentials as
# input variables. Every credential is fetched at plan-time from Vault using
# the Terraform AppRole defined in infra/vault/policies/terraform-deploy.hcl.
# Only Vault connection info is variable; everything else is data.
# =============================================================================

variable "vault_address" {
  description = "URL of the production Vault cluster, e.g. https://vault.yieldswarm.internal:8200"
  type        = string
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace, if any. Empty string for OSS."
  type        = string
  default     = ""
}

variable "vault_ca_cert_file" {
  description = "Path on the Terraform runner to the Vault CA bundle. Required for TLS verification."
  type        = string
  default     = "/etc/ssl/certs/yieldswarm-vault-ca.crt"
}

variable "vault_kv_mount" {
  description = "Mount path of the KV-v2 secrets engine that holds AgentSwarm secrets."
  type        = string
  default     = "yieldswarm"
}

variable "vault_approle_role_id" {
  description = <<-EOT
    AppRole role_id for the `terraform-deploy` principal.

    Inject via the CI environment as TF_VAR_vault_approle_role_id - never
    commit. The matching secret_id is provided via TF_VAR_vault_approle_secret_id
    or, preferably, via a response-wrapped token (see SECRETS.md).
  EOT
  type        = string
  sensitive   = true
}

variable "vault_approle_secret_id" {
  description = "AppRole secret_id for the `terraform-deploy` principal. Inject via CI only."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment: prod | staging | dev. Drives resource naming + tags."
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "default_tags" {
  description = "Tags applied to every cloud resource Terraform creates."
  type        = map(string)
  default = {
    project   = "yieldswarm"
    component = "agentswarm-os"
    managed   = "terraform"
  }
}

# --- Toggleable provider modules ---------------------------------------------
variable "enable_azure" {
  description = "Provision Azure resources."
  type        = bool
  default     = true
}

variable "enable_runpod" {
  description = "Provision RunPod GPU pods via the RunPod REST API (no native TF provider)."
  type        = bool
  default     = true
}

variable "enable_vultr" {
  description = "Provision Vultr instances."
  type        = bool
  default     = true
}

variable "enable_digitalocean" {
  description = "Provision DigitalOcean droplets / Spaces."
  type        = bool
  default     = true
}

variable "enable_rpc" {
  description = "Render RPC endpoint outputs (used by downstream Akash deploys)."
  type        = bool
  default     = true
}
