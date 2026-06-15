provider "vault" {
  address = coalesce(var.vault_address, getenv("VAULT_ADDR"))

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

module "secrets" {
  source = "./modules/secrets"
}

locals {
  azure = module.secrets.azure
  runpod = module.secrets.runpod
  vultr = module.secrets.vultr
  digitalocean = module.secrets.digitalocean
  rpc = module.secrets.rpc
}

provider "azurerm" {
  features {}

  subscription_id = local.azure.subscription_id
  tenant_id       = local.azure.tenant_id
  client_id       = local.azure.client_id
  client_secret   = local.azure.client_secret
}

provider "vultr" {
  api_key = local.vultr.api_key
}

provider "digitalocean" {
  token = local.digitalocean.token
}

provider "runpod" {
  api_key = local.runpod.api_key
}

locals {
  azure_rg_name = coalesce(var.azure_resource_group_name, local.azure.resource_group)
  azure_region  = coalesce(var.azure_location, local.azure.location)
}

resource "azurerm_resource_group" "agents" {
  name     = local.azure_rg_name
  location = local.azure_region

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "yieldswarm"
  }
}

# RPC configuration is consumed by downstream modules via outputs — never hardcoded.
output "rpc_endpoint_configured" {
  description = "Whether Solana RPC URL was loaded from Vault (value not exposed)."
  value       = length(local.rpc.solana_rpc_url) > 0
  sensitive   = false
}

output "azure_resource_group" {
  description = "Azure resource group name in use."
  value       = azurerm_resource_group.agents.name
}

output "azure_location" {
  description = "Azure region in use."
  value       = azurerm_resource_group.agents.location
}

output "environment" {
  value = var.environment
}
