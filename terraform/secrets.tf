# ============================================================
# Vault Data Sources — All Cloud & Service Credentials
#
# These data sources read live secret values from Vault at
# plan/apply time. Values are available as:
#   data.vault_generic_secret.<name>.data["<field>"]
#
# Sensitive = true means Terraform will never print values
# in plan output or state diffs.
# ============================================================

# ── Cloud providers ───────────────────────────────────────────

data "vault_generic_secret" "azure" {
  path = "secret/data/yieldswarm/azure"
}

data "vault_generic_secret" "runpod" {
  path = "secret/data/yieldswarm/runpod"
}

data "vault_generic_secret" "vultr" {
  path = "secret/data/yieldswarm/vultr"
}

data "vault_generic_secret" "do" {
  path = "secret/data/yieldswarm/do"
}

# ── RPC endpoints and blockchain infrastructure ───────────────

data "vault_generic_secret" "rpc" {
  path = "secret/data/yieldswarm/rpc"
}

# ── Agent runtime secrets ─────────────────────────────────────

data "vault_generic_secret" "core" {
  path = "secret/data/yieldswarm/core"
}

data "vault_generic_secret" "llm" {
  path = "secret/data/yieldswarm/llm"
}

data "vault_generic_secret" "blockchain" {
  path = "secret/data/yieldswarm/blockchain"
}

data "vault_generic_secret" "depin" {
  path = "secret/data/yieldswarm/depin"
}

# ── Third-party integrations ──────────────────────────────────

data "vault_generic_secret" "integrations" {
  path = "secret/data/yieldswarm/integrations"
}

# ── Monitoring & observability ────────────────────────────────

data "vault_generic_secret" "monitoring" {
  path = "secret/data/yieldswarm/monitoring"
}

# ── Akash deployment config ───────────────────────────────────

data "vault_generic_secret" "akash" {
  path = "secret/data/yieldswarm/akash"
}

# ── Convenience locals ────────────────────────────────────────
# Group frequently-used values under descriptive local names
# to keep resource files readable without repeating long paths.

locals {
  # Azure
  azure_subscription_id = data.vault_generic_secret.azure.data["subscription_id"]
  azure_tenant_id       = data.vault_generic_secret.azure.data["tenant_id"]
  azure_client_id       = data.vault_generic_secret.azure.data["client_id"]
  azure_client_secret   = data.vault_generic_secret.azure.data["client_secret"]

  # RunPod
  runpod_api_key     = data.vault_generic_secret.runpod.data["api_key"]
  runpod_endpoint    = data.vault_generic_secret.runpod.data["endpoint_url"]

  # Vultr
  vultr_api_key = data.vault_generic_secret.vultr.data["api_key"]

  # DigitalOcean
  do_token              = data.vault_generic_secret.do.data["token"]
  do_spaces_access_key  = data.vault_generic_secret.do.data["spaces_access_key"]
  do_spaces_secret_key  = data.vault_generic_secret.do.data["spaces_secret_key"]

  # RPC
  solana_rpc_url          = data.vault_generic_secret.rpc.data["solana_rpc_url"]
  helius_api_key          = data.vault_generic_secret.rpc.data["helius_api_key"]
  birdeye_api_key         = data.vault_generic_secret.rpc.data["birdeye_api_key"]
  erc4337_bundler_key     = data.vault_generic_secret.rpc.data["erc4337_bundler_key"]
  helix_chain_bridge_key  = data.vault_generic_secret.rpc.data["helix_chain_bridge_key"]

  # Integrations
  github_token        = data.vault_generic_secret.integrations.data["github_token"]
  vercel_api_token    = data.vault_generic_secret.integrations.data["vercel_api_token"]
  telegram_bot_token  = data.vault_generic_secret.integrations.data["telegram_bot_token"]

  # Common resource tags
  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    repo        = "yieldswarm-agent-swarm-v2"
  }
}
