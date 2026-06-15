# ============================================================
# RPC Configuration — YieldSwarm AgentSwarm OS
#
# This file consumes RPC secrets from Vault and:
#   1. Generates a runtime config file for agents that need
#      direct file-based RPC endpoint configuration.
#   2. Outputs RPC values for use by other Terraform resources
#      (e.g. smart-contract deployment, monitoring probes).
#
# Secret values are read from Vault — never hardcoded.
# The generated local file is gitignored and only exists in
# the CI/CD runner workspace during plan/apply.
# ============================================================

# ── RPC config file for agents ────────────────────────────────
# Written to the runner filesystem during Terraform runs;
# NOT committed to source control (.gitignore covers *.generated)
resource "local_sensitive_file" "rpc_config" {
  filename        = "${path.module}/.generated/rpc-config.json"
  file_permission = "0600"

  content = jsonencode({
    solana = {
      primary  = data.vault_generic_secret.rpc.data["solana_rpc_url"]
      helius   = "https://mainnet.helius-rpc.com/?api-key=${data.vault_generic_secret.rpc.data["helius_api_key"]}"
      failover = jsondecode(data.vault_generic_secret.rpc.data["failover_rpc_list"])
    }
    ethereum = {
      bundler = data.vault_generic_secret.rpc.data["erc4337_bundler_key"]
    }
    helix = {
      bridge_key = data.vault_generic_secret.rpc.data["helix_chain_bridge_key"]
    }
    ton = {
      api_key = data.vault_generic_secret.rpc.data["ton_api_key"]
    }
    tao = {
      subnet_key = data.vault_generic_secret.rpc.data["tao_subnet_key"]
    }
    zec = {
      shielded_key = data.vault_generic_secret.rpc.data["zec_shielded_key"]
    }
    birdeye = {
      api_key = data.vault_generic_secret.rpc.data["birdeye_api_key"]
    }
    jupiter = {
      api_key = data.vault_generic_secret.rpc.data["jupiter_api_key"]
    }
    raydium = {
      api_key = data.vault_generic_secret.rpc.data["raydium_api_key"]
    }
  })
}

# ── Ensure .generated directory exists ────────────────────────
resource "local_file" "generated_dir_marker" {
  filename = "${path.module}/.generated/.gitkeep"
  content  = ""
}
