provider "vault" {
  address   = var.vault_addr
  token     = var.vault_token
  namespace = var.vault_namespace
}

resource "vault_mount" "cloud" {
  path        = var.cloud_mount_path
  type        = "kv-v2"
  description = "Cloud provider credentials (Azure/RunPod/Vultr/DigitalOcean)."
}

resource "vault_mount" "rpc" {
  path        = var.rpc_mount_path
  type        = "kv-v2"
  description = "RPC endpoints and private credentials."
}

resource "vault_policy" "terraform_read" {
  name = var.terraform_policy_name

  policy = <<-EOT
  path "${var.cloud_mount_path}/data/azure" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/data/runpod" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/data/vultr" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/data/digitalocean" {
    capabilities = ["read"]
  }

  path "${var.rpc_mount_path}/data/rpc" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/metadata/*" {
    capabilities = ["read", "list"]
  }

  path "${var.rpc_mount_path}/metadata/*" {
    capabilities = ["read", "list"]
  }
  EOT
}

resource "vault_policy" "akash_runtime" {
  name = var.akash_policy_name

  policy = <<-EOT
  path "${var.cloud_mount_path}/data/runpod" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/data/vultr" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/data/digitalocean" {
    capabilities = ["read"]
  }

  path "${var.cloud_mount_path}/data/azure" {
    capabilities = ["read"]
  }

  path "${var.rpc_mount_path}/data/rpc" {
    capabilities = ["read"]
  }
  EOT
}

resource "vault_auth_backend" "approle" {
  path = "approle"
  type = "approle"
}

resource "vault_approle_auth_backend_role" "terraform_ci" {
  backend        = vault_auth_backend.approle.path
  role_name      = var.terraform_approle_name
  token_policies = [vault_policy.terraform_read.name]
  token_ttl      = "1h"
  token_max_ttl  = "4h"
}

resource "vault_auth_backend" "kubernetes" {
  path = var.kubernetes_auth_path
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_role" "akash_runtime" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "akash-runtime"
  bound_service_account_names      = var.akash_service_accounts
  bound_service_account_namespaces = [var.akash_namespace]
  token_policies                   = [vault_policy.akash_runtime.name]
  token_ttl                        = 3600
}

resource "vault_kv_secret_v2" "cloud_bootstrap" {
  for_each = var.cloud_bootstrap_secrets

  mount     = vault_mount.cloud.path
  name      = each.key
  data_json = jsonencode(each.value)
}

resource "vault_kv_secret_v2" "rpc_bootstrap" {
  for_each = var.rpc_bootstrap_secrets

  mount     = vault_mount.rpc.path
  name      = each.key
  data_json = jsonencode(each.value)
}

data "vault_kv_secret_v2" "azure" {
  count = var.read_runtime_secrets ? 1 : 0

  mount = vault_mount.cloud.path
  name  = "azure"
}

data "vault_kv_secret_v2" "runpod" {
  count = var.read_runtime_secrets ? 1 : 0

  mount = vault_mount.cloud.path
  name  = "runpod"
}

data "vault_kv_secret_v2" "vultr" {
  count = var.read_runtime_secrets ? 1 : 0

  mount = vault_mount.cloud.path
  name  = "vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  count = var.read_runtime_secrets ? 1 : 0

  mount = vault_mount.cloud.path
  name  = "digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  count = var.read_runtime_secrets ? 1 : 0

  mount = vault_mount.rpc.path
  name  = "rpc"
}

locals {
  azure_credentials = var.read_runtime_secrets ? {
    subscription_id = data.vault_kv_secret_v2.azure[0].data["subscription_id"]
    tenant_id       = data.vault_kv_secret_v2.azure[0].data["tenant_id"]
    client_id       = data.vault_kv_secret_v2.azure[0].data["client_id"]
    client_secret   = data.vault_kv_secret_v2.azure[0].data["client_secret"]
  } : {}

  runpod_credentials = var.read_runtime_secrets ? {
    api_key = data.vault_kv_secret_v2.runpod[0].data["api_key"]
  } : {}

  vultr_credentials = var.read_runtime_secrets ? {
    api_key = data.vault_kv_secret_v2.vultr[0].data["api_key"]
  } : {}

  digitalocean_credentials = var.read_runtime_secrets ? {
    token = data.vault_kv_secret_v2.digitalocean[0].data["token"]
  } : {}

  rpc_credentials = var.read_runtime_secrets ? {
    solana_primary_url   = data.vault_kv_secret_v2.rpc[0].data["solana_primary_url"]
    ethereum_primary_url = data.vault_kv_secret_v2.rpc[0].data["ethereum_primary_url"]
    fallback_urls_json   = try(data.vault_kv_secret_v2.rpc[0].data["fallback_urls_json"], "[]")
  } : {}
}
