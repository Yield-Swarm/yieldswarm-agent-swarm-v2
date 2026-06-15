# =============================================================================
# Single source of truth: every provider credential and RPC endpoint Terraform
# touches is pulled from Vault via a `vault_kv_secret_v2` data source.
#
# IMPORTANT: data sources are re-read on every `terraform plan`. Combined with
# the short-lived AppRole token (1h TTL, 24h max) this means a stolen
# tfstate file cannot be used to mint new infrastructure - the attacker would
# also need a live Vault AppRole credential.
# =============================================================================

# --- Infra provider credentials ---------------------------------------------
data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = "infra/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = "infra/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = "infra/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = "infra/digitalocean"
}

# --- RPC endpoints -----------------------------------------------------------
data "vault_kv_secret_v2" "rpc_solana" {
  mount = var.vault_kv_mount
  name  = "rpc/solana"
}

data "vault_kv_secret_v2" "rpc_ton" {
  mount = var.vault_kv_mount
  name  = "rpc/ton"
}

data "vault_kv_secret_v2" "rpc_tao" {
  mount = var.vault_kv_mount
  name  = "rpc/tao"
}

data "vault_kv_secret_v2" "rpc_helix" {
  mount = var.vault_kv_mount
  name  = "rpc/helix"
}

data "vault_kv_secret_v2" "rpc_zec" {
  mount = var.vault_kv_mount
  name  = "rpc/zec"
}

data "vault_kv_secret_v2" "rpc_erc4337" {
  mount = var.vault_kv_mount
  name  = "rpc/erc4337"
}

# --- Locals: typed views over the raw KV data, with helpful validation -----
locals {
  azure        = data.vault_kv_secret_v2.azure.data
  runpod       = data.vault_kv_secret_v2.runpod.data
  vultr        = data.vault_kv_secret_v2.vultr.data
  digitalocean = data.vault_kv_secret_v2.digitalocean.data

  rpc = {
    solana  = data.vault_kv_secret_v2.rpc_solana.data
    ton     = data.vault_kv_secret_v2.rpc_ton.data
    tao     = data.vault_kv_secret_v2.rpc_tao.data
    helix   = data.vault_kv_secret_v2.rpc_helix.data
    zec     = data.vault_kv_secret_v2.rpc_zec.data
    erc4337 = data.vault_kv_secret_v2.rpc_erc4337.data
  }
}

# --- Fail fast if anyone forgot to populate a real value --------------------
resource "null_resource" "fail_on_placeholders" {
  triggers = {
    azure_ok        = local.azure.subscription_id == "REPLACE_ME" ? "FAIL" : "OK"
    runpod_ok       = local.runpod.api_key == "REPLACE_ME" ? "FAIL" : "OK"
    vultr_ok        = local.vultr.api_key == "REPLACE_ME" ? "FAIL" : "OK"
    digitalocean_ok = local.digitalocean.api_token == "REPLACE_ME" ? "FAIL" : "OK"
  }

  lifecycle {
    precondition {
      condition = (
        local.azure.subscription_id != "REPLACE_ME" &&
        local.runpod.api_key != "REPLACE_ME" &&
        local.vultr.api_key != "REPLACE_ME" &&
        local.digitalocean.api_token != "REPLACE_ME"
      )
      error_message = "One or more provider credentials in Vault still hold the literal REPLACE_ME placeholder. Run `vault kv patch yieldswarm/infra/<provider> key=value` to set real values, then re-plan."
    }
  }
}
