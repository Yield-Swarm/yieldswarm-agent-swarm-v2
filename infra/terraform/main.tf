# =============================================================================
# Example resources — all gated OFF by default (see variables.tf toggles).
# These prove that each provider is correctly wired to Vault-sourced creds.
# Replace / extend with the real YieldSwarm infrastructure as it lands.
# =============================================================================

locals {
  common_tags = {
    project     = "yieldswarm"
    environment = var.environment
    managed_by  = "terraform"
    secrets     = "vault"
  }
}

# --- Azure ------------------------------------------------------------------
resource "azurerm_resource_group" "yieldswarm" {
  count    = var.enable_azure_examples ? 1 : 0
  name     = "yieldswarm-${var.environment}"
  location = var.azure_location
  tags     = local.common_tags
}

# --- DigitalOcean -----------------------------------------------------------
resource "digitalocean_project" "yieldswarm" {
  count       = var.enable_digitalocean_examples ? 1 : 0
  name        = "yieldswarm-${var.environment}"
  description = "YieldSwarm DePIN workloads (secrets via Vault)"
  purpose     = "Web Application"
  environment = title(var.environment)
}

# --- Vultr ------------------------------------------------------------------
# Demonstrates Vultr auth via the Vault-sourced api_key. Provide the public
# key out of band; it is not a secret.
variable "vultr_ssh_public_key" {
  description = "Public SSH key for the example Vultr key resource."
  type        = string
  default     = ""
}

resource "vultr_ssh_key" "yieldswarm" {
  count   = var.enable_vultr_examples && var.vultr_ssh_public_key != "" ? 1 : 0
  name    = "yieldswarm-${var.environment}"
  ssh_key = var.vultr_ssh_public_key
}

# --- RunPod -----------------------------------------------------------------
# The runpod provider is configured (providers.tf) with the Vault-sourced
# api_key. GPU pod/template resources are environment-specific; add them here
# once GPU sizing is finalised. Provider wiring is validated at plan time.
