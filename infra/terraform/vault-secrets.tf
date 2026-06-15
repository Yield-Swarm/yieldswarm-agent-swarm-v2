provider "vault" {
  address          = var.vault_addr
  namespace        = try(length(var.vault_namespace), 0) > 0 ? var.vault_namespace : null
  skip_child_token = true
}

data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = var.azure_secret_path
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = var.digitalocean_secret_path
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = var.runpod_secret_path
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = var.vultr_secret_path
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount
  name  = var.rpc_secret_path
}

locals {
  azure_secrets        = data.vault_kv_secret_v2.azure.data
  digitalocean_secrets = data.vault_kv_secret_v2.digitalocean.data
  runpod_secrets       = data.vault_kv_secret_v2.runpod.data
  vultr_secrets        = data.vault_kv_secret_v2.vultr.data
  rpc_secrets          = data.vault_kv_secret_v2.rpc.data
}
