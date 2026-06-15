# terraform/modules/vault-secrets/main.tf
#
# Single source of truth for every secret consumed elsewhere in Terraform.
# Other modules (azure/, runpod/, vultr/, digitalocean/, rpc/) take a typed
# object as input rather than reading from Vault directly. This keeps the
# Vault path layout in exactly one place and makes the modules unit-testable
# against synthetic inputs.
#
# All reads are vault_kv_secret_v2 data sources — never written to state
# in plaintext beyond the (already-sensitive) state file, which MUST live
# in an encrypted backend (see terraform/envs/prod/backend.tf).

data "vault_kv_secret_v2" "azure" {
  mount = var.kv_mount
  name  = "providers/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.kv_mount
  name  = "providers/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.kv_mount
  name  = "providers/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.kv_mount
  name  = "providers/digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  for_each = toset(var.rpc_chains)
  mount    = var.kv_mount
  name     = "rpc/${each.key}"
}
