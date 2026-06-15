# vault.tf
# Single point of truth for credential retrieval. Every other provider
# block sources its credentials from here - never from environment
# variables or tfvars files.
#
# Authentication model:
#   * Vault provider authenticates via AppRole (role_id + secret_id).
#   * The secret_id is delivered to Terraform via the TF_VAR_vault_auth_secret_id
#     env var. The companion wrapper `tf-with-vault.sh` mints (and, if
#     applicable, unwraps) the secret_id immediately before invoking
#     Terraform so the value never lingers in shell history.
#   * `skip_child_token = true` because the terraform-deployer policy
#     intentionally does NOT grant auth/token/create.

provider "vault" {
  address          = var.vault_address
  namespace        = var.vault_namespace
  skip_child_token = true

  auth_login {
    path = "auth/${var.vault_approle_mount}/login"
    parameters = {
      role_id   = var.vault_auth_role_id
      secret_id = var.vault_auth_secret_id
    }
  }
}

# --- Cloud provider credentials -----------------------------------------

data "vault_kv_secret_v2" "azure" {
  count = var.enable_azure ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/cloud/azure"
}

data "vault_kv_secret_v2" "runpod" {
  count = var.enable_runpod ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/cloud/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  count = var.enable_vultr ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/cloud/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  count = var.enable_digitalocean ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/cloud/digitalocean"
}

# --- RPC endpoints (consumed by both infra and workload templating) ------

data "vault_kv_secret_v2" "rpc_solana" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/rpc/solana"
}

data "vault_kv_secret_v2" "rpc_helius" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/rpc/helius"
}

data "vault_kv_secret_v2" "rpc_birdeye" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/rpc/birdeye"
}

data "vault_kv_secret_v2" "rpc_jupiter" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/rpc/jupiter"
}

data "vault_kv_secret_v2" "rpc_ethereum" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/rpc/ethereum"
}

# --- Akash deployer key handle ------------------------------------------

data "vault_kv_secret_v2" "akash_deployer" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_base}/akash/deployer"
}

# Convenience locals. All of these are marked sensitive so they NEVER
# appear in `terraform plan` or `terraform output` without an explicit
# `terraform output -raw`.
locals {
  azure        = var.enable_azure ? data.vault_kv_secret_v2.azure[0].data : {}
  runpod       = var.enable_runpod ? data.vault_kv_secret_v2.runpod[0].data : {}
  vultr        = var.enable_vultr ? data.vault_kv_secret_v2.vultr[0].data : {}
  digitalocean = var.enable_digitalocean ? data.vault_kv_secret_v2.digitalocean[0].data : {}

  rpc = {
    solana   = data.vault_kv_secret_v2.rpc_solana.data
    helius   = data.vault_kv_secret_v2.rpc_helius.data
    birdeye  = data.vault_kv_secret_v2.rpc_birdeye.data
    jupiter  = data.vault_kv_secret_v2.rpc_jupiter.data
    ethereum = data.vault_kv_secret_v2.rpc_ethereum.data
  }
}
