# =============================================================================
# Outputs. Provider wiring is proven without leaking secrets: the credential
# outputs are marked sensitive so they are never printed by the CLI/CI logs.
# =============================================================================

output "vault_kv_mount" {
  description = "KV v2 mount that backs every credential."
  value       = var.vault_kv_mount
}

output "azure_resource_group" {
  description = "Name of the example Azure resource group (if enabled)."
  value       = one(azurerm_resource_group.yieldswarm[*].name)
}

output "digitalocean_project_id" {
  description = "ID of the example DigitalOcean project (if enabled)."
  value       = one(digitalocean_project.yieldswarm[*].id)
}

# Sensitive — sourced from Vault, exposed only for downstream modules.
output "solana_rpc_url" {
  description = "Solana RPC endpoint pulled from Vault."
  value       = lookup(local.rpc_solana, "rpc_url", null)
  sensitive   = true
}

output "credential_source" {
  description = "Confirms credentials are resolved from Vault, not local files."
  value       = "hashicorp-vault://${var.vault_kv_mount}/yieldswarm/*"
}
