# rpc.tf
# RPC endpoint material is consumed in two places:
#   1. The Akash workload (injected via Vault at runtime - see akash-workload role).
#   2. Provider-specific resources here (e.g. Helius webhook registration,
#      Solana priority-fee oracles deployed as DO/Vultr droplets).
#
# To AVOID duplicating secret material in Terraform state for #1, we
# DO NOT export RPC keys as Terraform outputs. The Akash workload reads
# them directly from Vault at container start via its own AppRole.
#
# For #2, we publish RPC URLs (URLs are not secret) as outputs the rest
# of the stack can consume, but keep API keys gated behind sensitive
# outputs that require -raw to read.

# Example: register a Helius webhook pointing at our DO droplet. This is
# just a placeholder data-source illustrating that the key from Vault
# flows into a downstream provider (here, the http provider) without ever
# touching disk in plaintext outside of state.
data "http" "helius_health" {
  count = try(local.rpc.helius["api_key"], "") != "" ? 1 : 0
  url   = "${try(local.rpc.helius["url"], "https://api.helius.xyz")}/v0/health"
  request_headers = {
    "Authorization" = "Bearer ${local.rpc.helius["api_key"]}"
  }
  # We don't fail on non-200 here; this is a smoke check only.
  retry { attempts = 3 }
}

output "rpc_endpoints" {
  description = "Public RPC URLs (URLs only - never the API key)."
  value = {
    solana_primary   = try(local.rpc.solana["primary_url"], null)
    solana_failover  = try(local.rpc.solana["failover_url"], null)
    ethereum_primary = try(local.rpc.ethereum["primary_url"], null)
    helius_url       = try(local.rpc.helius["url"], null)
  }
}

# Sensitive shadow output - only readable via `terraform output -raw` and
# only meant for break-glass debugging. Stored as sensitive so it doesn't
# render to logs.
output "rpc_api_keys" {
  description = "Sensitive map of RPC API keys. Do not pipe to logs."
  sensitive   = true
  value = {
    helius  = try(local.rpc.helius["api_key"], null)
    birdeye = try(local.rpc.birdeye["api_key"], null)
    jupiter = try(local.rpc.jupiter["api_key"], null)
  }
}
