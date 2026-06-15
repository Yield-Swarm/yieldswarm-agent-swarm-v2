provider "vault" {
  address         = var.vault_address
  namespace       = var.vault_namespace
  ca_cert_file    = var.vault_ca_cert_file
  skip_tls_verify = var.vault_skip_tls_verify

  auth_login {
    path = "auth/${trim(var.vault_approle_mount_path, "/")}/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

ephemeral "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.azure
}

ephemeral "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.runpod
}

ephemeral "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.vultr
}

ephemeral "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.digitalocean
}

ephemeral "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount
  name  = var.vault_secret_paths.rpc
}

provider "azurerm" {
  features {}

  client_id                       = ephemeral.vault_kv_secret_v2.azure.data["client_id"]
  client_secret                   = ephemeral.vault_kv_secret_v2.azure.data["client_secret"]
  tenant_id                       = ephemeral.vault_kv_secret_v2.azure.data["tenant_id"]
  subscription_id                 = ephemeral.vault_kv_secret_v2.azure.data["subscription_id"]
  resource_provider_registrations = var.azurerm_resource_provider_registrations
}

provider "runpod" {
  api_key = ephemeral.vault_kv_secret_v2.runpod.data["api_key"]
}

provider "vultr" {
  api_key     = ephemeral.vault_kv_secret_v2.vultr.data["api_key"]
  rate_limit  = 100
  retry_limit = 3
}

provider "digitalocean" {
  token = ephemeral.vault_kv_secret_v2.digitalocean.data["token"]
}

locals {
  rpc = {
    primary_url   = ephemeral.vault_kv_secret_v2.rpc.data["primary_url"]
    websocket_url = try(ephemeral.vault_kv_secret_v2.rpc.data["websocket_url"], null)
    failover_urls = try(jsondecode(ephemeral.vault_kv_secret_v2.rpc.data["failover_urls_json"]), [])
    auth_header   = try(ephemeral.vault_kv_secret_v2.rpc.data["auth_header"], null)
  }

  vault_secret_contract = {
    azure = {
      path = "${var.vault_kv_mount}/data/${var.vault_secret_paths.azure}"
      required_keys = [
        "client_id",
        "client_secret",
        "tenant_id",
        "subscription_id",
      ]
    }
    runpod = {
      path          = "${var.vault_kv_mount}/data/${var.vault_secret_paths.runpod}"
      required_keys = ["api_key"]
    }
    vultr = {
      path          = "${var.vault_kv_mount}/data/${var.vault_secret_paths.vultr}"
      required_keys = ["api_key"]
    }
    digitalocean = {
      path          = "${var.vault_kv_mount}/data/${var.vault_secret_paths.digitalocean}"
      required_keys = ["token"]
    }
    rpc = {
      path = "${var.vault_kv_mount}/data/${var.vault_secret_paths.rpc}"
      required_keys = [
        "primary_url",
        "websocket_url",
        "failover_urls_json",
      ]
      optional_keys = [
        "auth_header",
      ]
    }
  }
}

output "vault_secret_contract" {
  description = "Required KV v2 paths and keys. This output contains no secret values."
  value       = local.vault_secret_contract
}
