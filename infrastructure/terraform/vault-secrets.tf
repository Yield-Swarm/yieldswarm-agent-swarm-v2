provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

data "vault_kv_secret_v2" "azure" {
  mount = var.vault_infra_mount
  name  = "providers/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_infra_mount
  name  = "providers/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_infra_mount
  name  = "providers/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_infra_mount
  name  = "providers/digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_infra_mount
  name  = "rpc/endpoints"
}

check "azure_secret_fields" {
  assert {
    condition = alltrue([
      for key in ["client_id", "client_secret", "tenant_id", "subscription_id"] :
      contains(keys(data.vault_kv_secret_v2.azure.data), key)
    ])
    error_message = "Vault secret kv-infra/providers/azure must include client_id, client_secret, tenant_id, and subscription_id."
  }
}

check "cloud_secret_fields" {
  assert {
    condition = alltrue([
      contains(keys(data.vault_kv_secret_v2.runpod.data), "api_key"),
      contains(keys(data.vault_kv_secret_v2.vultr.data), "api_key"),
      contains(keys(data.vault_kv_secret_v2.digitalocean.data), "token"),
    ])
    error_message = "Vault secrets must include runpod.api_key, vultr.api_key, and digitalocean.token."
  }
}

check "rpc_secret_fields" {
  assert {
    condition = alltrue([
      contains(keys(data.vault_kv_secret_v2.rpc.data), "primary_url"),
      contains(keys(data.vault_kv_secret_v2.rpc.data), "failover_urls_json"),
    ])
    error_message = "Vault secret kv-infra/rpc/endpoints must include primary_url and failover_urls_json."
  }
}

locals {
  azure_credentials = {
    client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
    tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
    subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
  }

  runpod_api_key      = data.vault_kv_secret_v2.runpod.data["api_key"]
  vultr_api_key       = data.vault_kv_secret_v2.vultr.data["api_key"]
  digitalocean_token  = data.vault_kv_secret_v2.digitalocean.data["token"]
  rpc_primary_url     = data.vault_kv_secret_v2.rpc.data["primary_url"]
  rpc_failover_urls   = jsondecode(data.vault_kv_secret_v2.rpc.data["failover_urls_json"])
}
