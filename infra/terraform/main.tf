provider "vault" {
  address   = var.vault_addr
  namespace = var.vault_namespace

  auth_login {
    path = "auth/${var.vault_approle_backend_path}/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

ephemeral "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount_path
  name  = "providers/azure"
}

ephemeral "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount_path
  name  = "providers/runpod"
}

ephemeral "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount_path
  name  = "providers/vultr"
}

ephemeral "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount_path
  name  = "providers/digitalocean"
}

ephemeral "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount_path
  name  = "network/rpc"
}

locals {
  azure = {
    client_id       = ephemeral.vault_kv_secret_v2.azure.data["client_id"]
    client_secret   = ephemeral.vault_kv_secret_v2.azure.data["client_secret"]
    subscription_id = ephemeral.vault_kv_secret_v2.azure.data["subscription_id"]
    tenant_id       = ephemeral.vault_kv_secret_v2.azure.data["tenant_id"]
  }

  runpod = {
    api_key = ephemeral.vault_kv_secret_v2.runpod.data["api_key"]
  }

  vultr = {
    api_key = ephemeral.vault_kv_secret_v2.vultr.data["api_key"]
  }

  digitalocean = {
    token = ephemeral.vault_kv_secret_v2.digitalocean.data["token"]
  }

  rpc = {
    primary_url   = ephemeral.vault_kv_secret_v2.rpc.data["primary_url"]
    websocket_url = try(ephemeral.vault_kv_secret_v2.rpc.data["websocket_url"], null)
    failover_urls = try(jsondecode(ephemeral.vault_kv_secret_v2.rpc.data["failover_urls_json"]), [])
    auth_header   = try(ephemeral.vault_kv_secret_v2.rpc.data["auth_header"], null)
  }
}

provider "azurerm" {
  features {}

  subscription_id = local.azure.subscription_id
  client_id       = local.azure.client_id
  client_secret   = local.azure.client_secret
  tenant_id       = local.azure.tenant_id
}

provider "runpod" {
  api_key = local.runpod.api_key
}

provider "vultr" {
  api_key = local.vultr.api_key
}

provider "digitalocean" {
  token = local.digitalocean.token
}
