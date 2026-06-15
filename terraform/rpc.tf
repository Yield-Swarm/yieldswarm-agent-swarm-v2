# RPC endpoints and failover list from Vault.
# Consumed by agents and cloud workloads — exported as Terraform outputs for wiring.

locals {
  primary_rpc = local.rpc_secrets.solana_rpc_url
  rpc_endpoints = concat(
    [local.primary_rpc],
    local.failover_rpc_list
  )
}

output "solana_rpc_url" {
  description = "Primary Solana RPC URL from Vault."
  value       = nonsensitive(local.primary_rpc)
}

output "failover_rpc_list" {
  description = "Failover RPC endpoints from Vault."
  value       = nonsensitive(local.failover_rpc_list)
}

output "rpc_endpoint_count" {
  description = "Total RPC endpoints (primary + failover)."
  value       = 1 + length(nonsensitive(local.failover_rpc_list))
}

# Non-sensitive metadata for observability dashboards.
output "rpc_providers_configured" {
  description = "Which RPC-related keys are present in Vault (not the values)."
  value = {
    helius_configured  = nonsensitive(local.rpc_secrets.helius_api_key) != "REPLACE_ME"
    birdeye_configured = nonsensitive(local.rpc_secrets.birdeye_api_key) != "REPLACE_ME"
    jupiter_configured = nonsensitive(local.rpc_secrets.jupiter_api_key) != "REPLACE_ME"
  }
}
