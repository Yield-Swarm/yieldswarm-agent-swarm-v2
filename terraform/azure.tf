provider "azurerm" {
  features {}

  client_id       = local.azure_creds["client_id"]
  client_secret   = local.azure_creds["client_secret"]
  subscription_id = local.azure_creds["subscription_id"]
  tenant_id       = local.azure_creds["tenant_id"]
}

resource "azurerm_resource_group" "agents" {
  name     = var.azure_resource_group_name
  location = var.azure_location

  tags = {
    environment = var.environment
    managed_by  = "terraform"
    project     = "yieldswarm-agentswarm"
  }
}

resource "azurerm_container_app_environment" "agents" {
  name                = "yieldswarm-agents-env"
  location            = azurerm_resource_group.agents.location
  resource_group_name = azurerm_resource_group.agents.name

  tags = {
    environment = var.environment
  }
}

# Container App for agent orchestration — secrets injected via Vault at runtime,
# not stored in Terraform state.
resource "azurerm_container_app" "orchestrator" {
  name                         = "yieldswarm-orchestrator"
  container_app_environment_id = azurerm_container_app_environment.agents.id
  resource_group_name          = azurerm_resource_group.agents.name
  revision_mode                = "Single"

  template {
    container {
      name   = "orchestrator"
      image  = "ghcr.io/yieldswarm/agentswarm:latest"
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

      env {
        name  = "SOLANA_RPC_URL"
        value = local.solana_rpc_url
      }
    }

    min_replicas = 1
    max_replicas = 3
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
    external_enabled = false
    target_port      = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    environment = var.environment
  }
}
