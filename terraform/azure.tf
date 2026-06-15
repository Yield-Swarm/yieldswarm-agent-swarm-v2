# terraform/azure.tf
# Azure infrastructure for YieldSwarm AgentSwarm OS v2.
# Credentials are sourced from Vault (local.azure.*) via vault_secrets.tf.
# The azurerm provider reads ARM_* env vars set by vault-env.sh.

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.azure_resource_group_name
  location = var.azure_location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Log Analytics Workspace (required for Container App Environment)
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-yieldswarm-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Container App Environment
# ---------------------------------------------------------------------------
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-yieldswarm-prod"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = var.tags
}

# ---------------------------------------------------------------------------
# Container App — Agent Swarm
# Vault-derived secrets are injected as container environment variables.
# Only VAULT_ADDR, VAULT_ROLE_ID, and VAULT_SECRET_ID reach the container;
# the entrypoint.sh fetches all other secrets at startup.
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "agents" {
  name                         = var.azure_container_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = var.tags

  template {
    min_replicas = var.azure_min_replicas
    max_replicas = var.azure_max_replicas

    container {
      name   = "agent-swarm"
      image  = var.azure_container_image
      cpu    = var.azure_container_cpu
      memory = var.azure_container_memory

      # Vault connection — the container's entrypoint.sh will use these to
      # authenticate and pull all other secrets at runtime.
      env {
        name  = "VAULT_ADDR"
        value = var.vault_addr
      }
      env {
        name        = "VAULT_ROLE_ID"
        secret_name = "vault-role-id"
      }
      env {
        name        = "VAULT_SECRET_ID"
        secret_name = "vault-secret-id"
      }

      # Agent shard config — safe, non-secret values
      env {
        name  = "AGENT_COUNT_TOTAL"
        value = "10080"
      }
      env {
        name  = "AGENTS_PER_SHARD"
        value = "84"
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 8080

        initial_delay    = 10
        interval_seconds = 30
        timeout          = 5
        failure_count_threshold = 3
      }

      readiness_probe {
        transport = "HTTP"
        path      = "/ready"
        port      = 8080

        initial_delay    = 5
        interval_seconds = 10
        timeout          = 3
      }
    }
  }

  # Secrets stored in Container App (Vault AppRole credentials only)
  secret {
    name  = "vault-role-id"
    value = local.azure["subscription_id"] != "REPLACE_ME" ? (
      # Production: read the akash-agent role_id from Vault (stored by ops)
      # For now, placeholder — operators populate after vault/setup.sh
      local.azure["subscription_id"]
    ) : "CONFIGURE_ME_SEE_SECRETS_MD"
  }

  secret {
    name  = "vault-secret-id"
    value = "CONFIGURE_ME_SEE_SECRETS_MD"
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8080

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  lifecycle {
    ignore_changes = [
      # Vault secret_ids are rotated out-of-band; don't overwrite on every apply
      secret,
    ]
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "azure_resource_group" {
  description = "Name of the Azure resource group."
  value       = azurerm_resource_group.main.name
}

output "azure_container_app_fqdn" {
  description = "FQDN of the Container App (public ingress URL)."
  value       = azurerm_container_app.agents.ingress[0].fqdn
}
