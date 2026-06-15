# =========================================================================
# RPC plane: the RPC creds aren't tied to a single cloud, they're packed
# into a Kubernetes/Azure/Vercel secret bundle consumed by every agent
# shard. We emit them as a single, sensitive output that downstream
# modules can consume via terraform_remote_state.
#
# All values come straight from Vault and are marked sensitive end-to-end.
# =========================================================================

output "rpc_bundle" {
  description = "RPC endpoints + API keys for downstream agent modules."
  sensitive   = true
  value = {
    helius = {
      api_key = local.rpc_endpoints.helius_api_key
    }
    birdeye = {
      api_key = local.rpc_endpoints.birdeye_api_key
    }
    jupiter = {
      api_key = local.rpc_endpoints.jupiter_api_key
    }
    raydium = {
      api_key = local.rpc_endpoints.raydium_api_key
    }
    ton = {
      api_key = local.rpc_endpoints.ton_api_key
    }
    solana = {
      http_url = local.rpc_endpoints.solana_http_url
      ws_url   = local.rpc_endpoints.solana_ws_url
    }
  }
}

# Health check: ensure every RPC secret was actually populated. Fail
# fast in `terraform plan` if Vault returned an empty string.
resource "terraform_data" "rpc_health" {
  input = {
    for k, v in local.rpc_endpoints :
    k => length(v) > 0
  }

  lifecycle {
    precondition {
      condition     = alltrue([for v in values(local.rpc_endpoints) : length(v) > 0])
      error_message = "One or more RPC secrets in Vault are empty - re-run vault/setup/05-seed-secrets.sh."
    }
  }
}
