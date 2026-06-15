# Vault data sources — the single source of truth for all provider credentials.
#
# Every secret consumed by Terraform is read from Vault at plan/apply time. No
# credential is ever written to disk, committed, or passed on the command line.
# Each data source maps to a path seeded by infra/vault/seed-secrets.sh.

# Azure service principal credentials.
data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/azure"
}

# RunPod API key.
data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/runpod"
}

# Vultr API key.
data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/vultr"
}

# DigitalOcean personal access token.
data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/digitalocean"
}

# Blockchain / RPC endpoints and keys.
data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/rpc"
}

locals {
  azure        = data.vault_kv_secret_v2.azure.data
  runpod       = data.vault_kv_secret_v2.runpod.data
  vultr        = data.vault_kv_secret_v2.vultr.data
  digitalocean = data.vault_kv_secret_v2.digitalocean.data
  rpc          = data.vault_kv_secret_v2.rpc.data
}
