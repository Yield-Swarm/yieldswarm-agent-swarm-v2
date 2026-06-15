# =========================================================================
# Pull every secret from Vault. The Vault provider authenticates with
# VAULT_ADDR + VAULT_TOKEN from env (typically a short-lived token minted
# via the `terraform` AppRole - see ../scripts/vault-login.sh and SECRETS.md).
#
# No secret value is written to terraform.tfvars, *.auto.tfvars, or the
# environment of `terraform apply` callers. Reads here become sensitive
# attributes on the data sources, which Terraform will redact in plan
# output by default (provider declares them sensitive).
# =========================================================================

provider "vault" {
  # Falls back to VAULT_ADDR env var when var.vault_address is empty.
  address               = var.vault_address
  max_lease_ttl_seconds = 1800
  skip_child_token      = true
}

# ---- Cloud providers ---------------------------------------------------
data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = "cloud/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = "cloud/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = "cloud/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = "cloud/digitalocean"
}

# ---- RPC providers -----------------------------------------------------
data "vault_kv_secret_v2" "rpc_helius" {
  mount = var.vault_kv_mount
  name  = "rpc/helius"
}

data "vault_kv_secret_v2" "rpc_birdeye" {
  mount = var.vault_kv_mount
  name  = "rpc/birdeye"
}

data "vault_kv_secret_v2" "rpc_jupiter" {
  mount = var.vault_kv_mount
  name  = "rpc/jupiter"
}

data "vault_kv_secret_v2" "rpc_solana" {
  mount = var.vault_kv_mount
  name  = "rpc/solana"
}

data "vault_kv_secret_v2" "rpc_raydium" {
  mount = var.vault_kv_mount
  name  = "rpc/raydium"
}

data "vault_kv_secret_v2" "rpc_ton" {
  mount = var.vault_kv_mount
  name  = "rpc/ton"
}

# --- AppRole role_id + freshly minted wrapped SecretID per workload ----
# Generated at apply time so we never have to seed them into KV.
data "vault_approle_auth_backend_role_id" "agent_runtime" {
  backend   = "approle"
  role_name = "agent-runtime"
}

resource "vault_approle_auth_backend_role_secret_id" "azure_agent" {
  backend      = "approle"
  role_name    = "agent-runtime"
  wrapping_ttl = "30m"
  metadata = jsonencode({
    workload = "azure-agent"
    env      = var.environment
  })
}

resource "vault_approle_auth_backend_role_secret_id" "runpod_agent" {
  backend      = "approle"
  role_name    = "agent-runtime"
  wrapping_ttl = "30m"
  metadata = jsonencode({
    workload = "runpod-agent"
    env      = var.environment
  })
}

resource "vault_approle_auth_backend_role_secret_id" "vultr_agent" {
  backend      = "approle"
  role_name    = "agent-runtime"
  wrapping_ttl = "30m"
  metadata = jsonencode({
    workload = "vultr-agent"
    env      = var.environment
  })
}

resource "vault_approle_auth_backend_role_secret_id" "do_agent" {
  backend      = "approle"
  role_name    = "agent-runtime"
  wrapping_ttl = "30m"
  metadata = jsonencode({
    workload = "do-agent"
    env      = var.environment
  })
}

locals {
  azure_creds = {
    client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
    tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
    subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
  }

  agent_role_id = data.vault_approle_auth_backend_role_id.agent_runtime.role_id

  rpc_endpoints = {
    helius_api_key  = data.vault_kv_secret_v2.rpc_helius.data["api_key"]
    birdeye_api_key = data.vault_kv_secret_v2.rpc_birdeye.data["api_key"]
    jupiter_api_key = data.vault_kv_secret_v2.rpc_jupiter.data["api_key"]
    raydium_api_key = data.vault_kv_secret_v2.rpc_raydium.data["api_key"]
    ton_api_key     = data.vault_kv_secret_v2.rpc_ton.data["api_key"]
    solana_http_url = data.vault_kv_secret_v2.rpc_solana.data["http_url"]
    solana_ws_url   = data.vault_kv_secret_v2.rpc_solana.data["ws_url"]
  }
}
