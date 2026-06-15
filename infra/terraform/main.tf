provider "vault" {
  address = var.vault_addr
}

locals {
  secret_prefix = "${trim(var.vault_secret_base_path, "/")}/${var.environment}"
}

data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = "${local.secret_prefix}/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = "${local.secret_prefix}/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = "${local.secret_prefix}/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = "${local.secret_prefix}/digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount
  name  = "${local.secret_prefix}/rpc"
}

locals {
  azure_credentials = {
    subscription_id = nonsensitive(data.vault_kv_secret_v2.azure.data["subscription_id"])
    tenant_id       = nonsensitive(data.vault_kv_secret_v2.azure.data["tenant_id"])
    client_id       = nonsensitive(data.vault_kv_secret_v2.azure.data["client_id"])
    client_secret   = nonsensitive(data.vault_kv_secret_v2.azure.data["client_secret"])
  }

  runpod_credentials = {
    api_key = nonsensitive(data.vault_kv_secret_v2.runpod.data["api_key"])
  }

  vultr_credentials = {
    api_key = nonsensitive(data.vault_kv_secret_v2.vultr.data["api_key"])
  }

  digitalocean_credentials = {
    token = nonsensitive(data.vault_kv_secret_v2.digitalocean.data["token"])
  }

  rpc_settings = {
    primary_url   = nonsensitive(data.vault_kv_secret_v2.rpc.data["primary_url"])
    failover_json = nonsensitive(data.vault_kv_secret_v2.rpc.data["failover_json"])
  }

  missing_required_keys = compact([
    for k in ["subscription_id", "tenant_id", "client_id", "client_secret"] :
    contains(keys(data.vault_kv_secret_v2.azure.data), k) ? "" : "azure.${k}"
  ] ++ [
    for k in ["api_key"] :
    contains(keys(data.vault_kv_secret_v2.runpod.data), k) ? "" : "runpod.${k}"
  ] ++ [
    for k in ["api_key"] :
    contains(keys(data.vault_kv_secret_v2.vultr.data), k) ? "" : "vultr.${k}"
  ] ++ [
    for k in ["token"] :
    contains(keys(data.vault_kv_secret_v2.digitalocean.data), k) ? "" : "digitalocean.${k}"
  ] ++ [
    for k in ["primary_url", "failover_json"] :
    contains(keys(data.vault_kv_secret_v2.rpc.data), k) ? "" : "rpc.${k}"
  ])
}

resource "terraform_data" "secrets_contract" {
  input = {
    cloud_and_rpc_paths = [
      data.vault_kv_secret_v2.azure.name,
      data.vault_kv_secret_v2.runpod.name,
      data.vault_kv_secret_v2.vultr.name,
      data.vault_kv_secret_v2.digitalocean.name,
      data.vault_kv_secret_v2.rpc.name,
    ]
  }

  lifecycle {
    precondition {
      condition     = length(local.missing_required_keys) == 0
      error_message = "Vault secret contract is incomplete. Missing keys: ${join(", ", local.missing_required_keys)}"
    }
  }
}
