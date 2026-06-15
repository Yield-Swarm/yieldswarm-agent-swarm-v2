resource "azurerm_resource_group" "yieldswarm" {
  name     = local.azure.resource_group
  location = local.azure.location
  tags     = local.common_tags
}

# Container Apps environment for agent workloads — secrets injected at runtime via Vault Agent sidecar.
resource "azurerm_container_app_environment" "agents" {
  name                = "yieldswarm-agents-${var.environment}"
  location            = azurerm_resource_group.yieldswarm.location
  resource_group_name = azurerm_resource_group.yieldswarm.name
  tags                = local.common_tags
}

# Non-sensitive config only — runtime secrets come from Vault, not Terraform.
resource "azurerm_container_app" "agent_orchestrator" {
  name                         = "agent-orchestrator"
  container_app_environment_id = azurerm_container_app_environment.agents.id
  resource_group_name          = azurerm_resource_group.yieldswarm.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  template {
    container {
      name   = "orchestrator"
      image  = "yieldswarm/agentswarm:latest"
      cpu    = 1.0
      memory = "2Gi"

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

      # RPC endpoint is non-sensitive URL; API keys injected at runtime by Vault Agent.
      env {
        name  = "SOLANA_RPC_URL"
        value = local.rpc.solana_rpc_url
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  secret {
    name  = "vault-role-id"
    value = var.vault_role_id
  }

  secret {
    name  = "vault-secret-id"
    value = var.vault_secret_id
  }

  ingress {
    external_enabled = true
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
