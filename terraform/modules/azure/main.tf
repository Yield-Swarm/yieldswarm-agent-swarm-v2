# ---------------------------------------------------------------------------
# modules/azure/main.tf
# Azure Container Apps environment for AgentSwarm shards.
# Credentials arrive via variables sourced from Vault in the root module.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "agentswarm" {
  name     = var.resource_group
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Log Analytics workspace (required by Container Apps)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "agentswarm" {
  name                = "${local.name_prefix}-logs"
  location            = azurerm_resource_group.agentswarm.location
  resource_group_name = azurerm_resource_group.agentswarm.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Container Apps environment
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "agentswarm" {
  name                       = "${local.name_prefix}-env"
  location                   = azurerm_resource_group.agentswarm.location
  resource_group_name        = azurerm_resource_group.agentswarm.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.agentswarm.id
  tags                       = local.tags
}

# ---------------------------------------------------------------------------
# Storage account for agent state and logs
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "agentswarm" {
  name                     = replace("${local.name_prefix}store", "-", "")
  resource_group_name      = azurerm_resource_group.agentswarm.name
  location                 = azurerm_resource_group.agentswarm.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

resource "azurerm_storage_container" "agent_state" {
  name                  = "agent-state"
  storage_account_id    = azurerm_storage_account.agentswarm.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "agent_logs" {
  name                  = "agent-logs"
  storage_account_id    = azurerm_storage_account.agentswarm.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Container Apps — one app per shard, each shard runs agents_per_shard agents.
# VAULT_ROLE_ID is non-sensitive; VAULT_SECRET_ID is a wrapped token injected
# as a secret so it is never stored in the resource's plain-text properties.
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "shard" {
  count = var.shard_count

  name                         = "${local.name_prefix}-shard-${format("%03d", count.index)}"
  container_app_environment_id = azurerm_container_app_environment.agentswarm.id
  resource_group_name          = azurerm_resource_group.agentswarm.name
  revision_mode                = "Single"
  tags                         = local.tags

  secret {
    name  = "vault-secret-id"
    value = var.vault_approle_secret_id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "agent"
      image  = var.agent_image
      cpu    = var.cpu
      memory = var.memory

      # Non-sensitive configuration
      env {
        name  = "VAULT_ADDR"
        value = var.vault_addr
      }
      env {
        name  = "VAULT_ROLE_ID"
        value = var.vault_approle_role_id
      }
      env {
        name        = "VAULT_SECRET_ID"
        secret_name = "vault-secret-id"
      }
      env {
        name  = "AGENT_SHARD_ID"
        value = tostring(count.index)
      }
      env {
        name  = "AGENTS_PER_SHARD"
        value = tostring(var.agents_per_shard)
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/healthz"
        port      = 8080
        initial_delay    = 15
        period_seconds   = 30
        failure_count_threshold = 3
      }
    }
  }
}
