## RPC module - consumes the per-chain RPC secrets supplied via Vault and
## re-publishes a curated, namespaced view at
## `kv/data/yieldswarm/<env>/runtime/rpc-resolved` for downstream workloads
## that should not be granted access to every chain's raw secret.

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.4"
    }
  }
}

locals {
  resolved = {
    solana = {
      url             = var.rpc_secrets.solana.url
      helius_api_key  = var.rpc_secrets.solana.helius_api_key
      jupiter_api_key = var.rpc_secrets.solana.jupiter_api_key
      birdeye_api_key = var.rpc_secrets.solana.birdeye_api_key
      raydium_api_key = var.rpc_secrets.solana.raydium_api_key
    }
    eth = {
      mainnet_url = var.rpc_secrets.eth.mainnet_url
      sepolia_url = var.rpc_secrets.eth.sepolia_url
      bundler_url = var.rpc_secrets.eth.bundler_url
    }
    ton = {
      url     = var.rpc_secrets.ton.url
      api_key = var.rpc_secrets.ton.api_key
    }
    tao = {
      url        = var.rpc_secrets.tao.url
      subnet_key = var.rpc_secrets.tao.subnet_key
    }
  }
}

resource "vault_kv_secret_v2" "resolved" {
  mount               = var.vault_kv_mount
  name                = "yieldswarm/${var.environment}/runtime/rpc-resolved"
  cas                 = 0
  delete_all_versions = false
  data_json           = jsonencode(local.resolved)

  custom_metadata {
    max_versions = 10
    data = {
      managed_by   = "terraform"
      environment  = var.environment
      last_applied = timestamp()
    }
  }
}
