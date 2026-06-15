variable "credentials" {
  description = "Azure SP credentials (typically piped from module.vault_secrets.azure)."
  type = object({
    client_id       = string
    client_secret   = string
    tenant_id       = string
    subscription_id = string
  })
  sensitive = true

  validation {
    condition = (
      var.credentials.client_id != null && var.credentials.client_id != "" &&
      var.credentials.client_secret != null && var.credentials.client_secret != "" &&
      var.credentials.tenant_id != null && var.credentials.tenant_id != "" &&
      var.credentials.subscription_id != null && var.credentials.subscription_id != ""
    )
    error_message = "Azure credentials are incomplete. Run vault/scripts/seed-secrets.sh with AZURE_* env vars set."
  }
}

variable "location" {
  description = "Default Azure region."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group that holds the AgentSwarm Azure footprint."
  type        = string
  default     = "yieldswarm-prod-rg"
}

variable "tags" {
  description = "Common tags applied to every Azure resource."
  type        = map(string)
  default = {
    project     = "yieldswarm"
    managed_by  = "terraform"
    secrets_src = "vault"
  }
}
