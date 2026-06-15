output "rpc_primary_url" {
  description = "Primary RPC endpoint loaded from Vault."
  value       = local.rpc_primary_url
  sensitive   = true
}

output "rpc_failover_urls" {
  description = "Failover RPC endpoint list loaded from Vault."
  value       = local.rpc_failover_urls
  sensitive   = true
}
