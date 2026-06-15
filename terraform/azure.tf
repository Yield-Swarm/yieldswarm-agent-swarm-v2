# =========================================================================
# Azure: resource group + Container App Environment for long-running agent
# shards (the Vercel-incompatible ones). Credentials come from Vault via
# the azurerm provider configured in providers.tf.
# =========================================================================

resource "azurerm_resource_group" "yieldswarm" {
  name     = "rg-yieldswarm-${var.environment}"
  location = var.azure_location

  tags = {
    project     = "yieldswarm"
    environment = var.environment
    managed_by  = "terraform"
    secrets     = "vault"
  }
}

resource "azurerm_log_analytics_workspace" "agents" {
  name                = "log-yieldswarm-${var.environment}"
  resource_group_name = azurerm_resource_group.yieldswarm.name
  location            = azurerm_resource_group.yieldswarm.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "agents" {
  name                       = "cae-yieldswarm-${var.environment}"
  location                   = azurerm_resource_group.yieldswarm.location
  resource_group_name        = azurerm_resource_group.yieldswarm.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.agents.id
}

# Agent shards on Azure Container Apps. Every shard inherits the Vault
# AppRole creds from environment variables that are themselves sourced
# from Vault at apply time (so the literal value is never on disk).
resource "azurerm_container_app" "agent_shard" {
  count                        = var.agent_shard_count
  name                         = "agent-shard-${count.index}"
  container_app_environment_id = azurerm_container_app_environment.agents.id
  resource_group_name          = azurerm_resource_group.yieldswarm.name
  revision_mode                = "Single"

  template {
    container {
      name   = "agent"
      image  = "ghcr.io/yield-swarm/yieldswarm-agent:latest"
      cpu    = 0.5
      memory = "1Gi"

      # The agent boots via the same Vault Agent entrypoint as Akash and
      # pulls its own secrets. Only the AppRole role_id (non-secret) and
      # the wrapped SecretID are passed in here.
      env {
        name  = "VAULT_ADDR"
        value = "https://vault.yieldswarm.io:8200"
      }
      env {
        name  = "VAULT_ROLE_ID"
        value = local.agent_role_id
      }
      env {
        name        = "VAULT_WRAPPED_SECRET_ID"
        secret_name = "vault-wrapped-secret-id"
      }
      env {
        name  = "AGENT_SHARD_ID"
        value = tostring(count.index)
      }
    }
  }

  secret {
    name  = "vault-wrapped-secret-id"
    value = vault_approle_auth_backend_role_secret_id.azure_agent.wrapping_token
  }

  tags = {
    project     = "yieldswarm"
    environment = var.environment
    shard       = count.index
  }
}
