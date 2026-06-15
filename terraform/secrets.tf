# ---------------------------------------------------------------------------
# terraform/secrets.tf
# Vault KV v2 data sources — all provider credentials live here.
# Nothing in this file is a secret itself; it is just a declaration of
# which Vault paths to read. Actual values are never written to this file.
# ---------------------------------------------------------------------------

# Cloud provider credentials
data "vault_kv_secret_v2" "azure" {
  mount = "secret"
  name  = "agentswarm/cloud/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = "secret"
  name  = "agentswarm/cloud/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = "secret"
  name  = "agentswarm/cloud/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = "secret"
  name  = "agentswarm/cloud/digitalocean"
}

# Blockchain RPC endpoints (used to configure agent container env vars
# and any Terraform-managed infrastructure that acts as an RPC proxy)
data "vault_kv_secret_v2" "rpc" {
  mount = "secret"
  name  = "agentswarm/rpc"
}

# Integration tokens (GitHub for registry, Vercel for edge)
data "vault_kv_secret_v2" "integrations" {
  mount = "secret"
  name  = "agentswarm/integrations"
}

# ---------------------------------------------------------------------------
# Local values — expose individual fields with sensible names.
# Mark everything as sensitive so Terraform redacts them in plan output.
# ---------------------------------------------------------------------------
locals {
  # Azure
  azure_subscription_id = sensitive(data.vault_kv_secret_v2.azure.data["subscription_id"])
  azure_tenant_id       = sensitive(data.vault_kv_secret_v2.azure.data["tenant_id"])
  azure_client_id       = sensitive(data.vault_kv_secret_v2.azure.data["client_id"])
  azure_client_secret   = sensitive(data.vault_kv_secret_v2.azure.data["client_secret"])
  azure_resource_group  = data.vault_kv_secret_v2.azure.data["resource_group"]
  azure_location        = data.vault_kv_secret_v2.azure.data["location"]

  # RunPod
  runpod_api_key           = sensitive(data.vault_kv_secret_v2.runpod.data["api_key"])
  runpod_network_volume_id = data.vault_kv_secret_v2.runpod.data["network_volume_id"]

  # Vultr
  vultr_api_key = sensitive(data.vault_kv_secret_v2.vultr.data["api_key"])

  # DigitalOcean
  do_token             = sensitive(data.vault_kv_secret_v2.digitalocean.data["token"])
  do_spaces_access_id  = sensitive(data.vault_kv_secret_v2.digitalocean.data["spaces_access_id"])
  do_spaces_secret_key = sensitive(data.vault_kv_secret_v2.digitalocean.data["spaces_secret_key"])

  # RPC
  solana_rpc_url         = sensitive(data.vault_kv_secret_v2.rpc.data["solana_rpc_url"])
  helius_api_key         = sensitive(data.vault_kv_secret_v2.rpc.data["helius_api_key"])
  birdeye_api_key        = sensitive(data.vault_kv_secret_v2.rpc.data["birdeye_api_key"])
  jupiter_api_key        = sensitive(data.vault_kv_secret_v2.rpc.data["jupiter_api_key"])
  helix_chain_bridge_key = sensitive(data.vault_kv_secret_v2.rpc.data["helix_chain_bridge_key"])

  # Integrations
  github_token       = sensitive(data.vault_kv_secret_v2.integrations.data["github_token"])
  vercel_api_token   = sensitive(data.vault_kv_secret_v2.integrations.data["vercel_api_token"])
  telegram_bot_token = sensitive(data.vault_kv_secret_v2.integrations.data["telegram_bot_token"])
}
