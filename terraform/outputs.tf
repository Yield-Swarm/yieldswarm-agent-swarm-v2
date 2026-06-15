# =============================================================================
# Terraform Outputs
# YieldSwarm AgentSwarm OS v2.0
#
# All secret-derived outputs are marked sensitive = true.
# Run `terraform output -json` to read them (requires appropriate Vault token).
# =============================================================================

# ---------------------------------------------------------------------------
# Azure
# ---------------------------------------------------------------------------
output "azure_resource_group" {
  description = "Azure resource group name"
  value       = azurerm_resource_group.agents.name
}

output "azure_container_app_env_id" {
  description = "Azure Container App Environment ID"
  value       = azurerm_container_app_environment.agents.id
}

output "azure_key_vault_id" {
  description = "Azure Key Vault ID used for Vault auto-unseal"
  value       = azurerm_key_vault.vault_unseal.id
}

output "azure_key_vault_uri" {
  description = "Azure Key Vault URI"
  value       = azurerm_key_vault.vault_unseal.vault_uri
}

output "azure_unseal_key_id" {
  description = "Azure Key Vault RSA key ID for Vault auto-unseal"
  value       = azurerm_key_vault_key.vault_unseal.id
  sensitive   = true
}

# ---------------------------------------------------------------------------
# DigitalOcean
# ---------------------------------------------------------------------------
output "do_droplet_ip" {
  description = "DigitalOcean agent droplet public IP"
  value       = digitalocean_droplet.agentswarm_node.ipv4_address
}

# ---------------------------------------------------------------------------
# Vultr
# ---------------------------------------------------------------------------
output "vultr_instance_ip" {
  description = "Vultr agent instance public IP"
  value       = vultr_instance.agentswarm_node.main_ip
}

# ---------------------------------------------------------------------------
# RPC endpoints (sensitive — do not log)
# ---------------------------------------------------------------------------
output "rpc_primary_url" {
  description = "Primary Solana RPC URL"
  value       = data.vault_kv_secret_v2.rpc_solana.data["primary_url"]
  sensitive   = true
}

output "rpc_helius_api_key" {
  description = "Helius API key"
  value       = data.vault_kv_secret_v2.rpc_solana.data["helius_api_key"]
  sensitive   = true
}

output "rpc_failover_list" {
  description = "Solana RPC failover list (JSON)"
  value       = data.vault_kv_secret_v2.rpc_solana.data["failover_list"]
  sensitive   = true
}
