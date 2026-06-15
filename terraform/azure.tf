# ============================================================
# Azure Infrastructure — YieldSwarm AgentSwarm OS
#
# Resources provisioned here:
#   - Resource group (if not pre-existing)
#   - Azure Container Registry (ACR) for agent images
#   - Azure Container Apps Environment + agent app
#   - Key Vault reference (read-only; secrets live in Vault)
#   - Log Analytics workspace for monitoring
#
# All credentials come from data.vault_generic_secret.azure
# via the local.azure_* convenience locals in secrets.tf.
# ============================================================

# ── Resource group ────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.azure_resource_group
  location = var.azure_location
  tags     = local.common_tags
}

# ── Log Analytics workspace ───────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-logs-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# ── Azure Container Registry ──────────────────────────────────
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project_name, "-", "")}${var.environment}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.azure_container_registry_sku
  admin_enabled       = false  # use managed identity, not admin credentials

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# ── Container Apps Environment ────────────────────────────────
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-cae-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

# ── Container App — AgentSwarm Worker ─────────────────────────
# Secrets are not stored in Azure; the container fetches them
# from Vault at runtime via the entrypoint script.
resource "azurerm_container_app" "agentswarm" {
  name                         = "${var.project_name}-agentswarm-${var.environment}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  template {
    min_replicas = 1
    max_replicas = 10

    container {
      name   = "agentswarm"
      image  = "${azurerm_container_registry.main.login_server}/agentswarm:latest"
      cpu    = 0.5
      memory = "1Gi"

      # Only Vault connection parameters are injected here.
      # All other secrets are fetched inside the container.
      env {
        name  = "VAULT_ADDR"
        value = var.vault_address
      }
      env {
        name        = "VAULT_ROLE_ID"
        secret_name = "vault-role-id"
      }
      env {
        name        = "VAULT_SECRET_ID"
        secret_name = "vault-secret-id"
      }
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
      env {
        name  = "AGENT_COUNT_TOTAL"
        value = tostring(var.agent_count_total)
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
        interval_seconds = 30
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/ready"
        port      = 8080
        initial_delay    = 5
        interval_seconds = 10
      }
    }
  }

  # Vault AppRole credentials stored as Container App secrets
  # (the only two non-Vault secrets needed to bootstrap Vault access)
  secret {
    name  = "vault-role-id"
    value = var.vault_role_id
  }

  secret {
    name  = "vault-secret-id"
    value = var.vault_secret_id
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  lifecycle {
    ignore_changes = [
      # Image tag is updated by CI/CD, not Terraform
      template[0].container[0].image,
    ]
  }
}

# ── ACR pull permission for Container App ─────────────────────
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_container_app.agentswarm.identity[0].principal_id
}
