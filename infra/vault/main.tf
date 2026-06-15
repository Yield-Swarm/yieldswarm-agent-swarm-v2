locals {
  cloud_mount_path   = "cloud"
  rpc_mount_path     = "rpc"
  apps_mount_path    = "apps"
  transit_mount_path = "transit"

  secret_contracts = {
    azure = {
      mount           = local.cloud_mount_path
      name            = "azure"
      required_fields = ["subscription_id", "tenant_id", "client_id", "client_secret"]
    }
    runpod = {
      mount           = local.cloud_mount_path
      name            = "runpod"
      required_fields = ["api_key"]
    }
    vultr = {
      mount           = local.cloud_mount_path
      name            = "vultr"
      required_fields = ["api_key"]
    }
    digitalocean = {
      mount           = local.cloud_mount_path
      name            = "digitalocean"
      required_fields = ["token"]
    }
    rpc = {
      mount = local.rpc_mount_path
      name  = "mainnet"
      required_fields = [
        "SOLANA_RPC_URL",
        "HELIUS_API_KEY",
        "BIRDEYE_API_KEY",
        "JUPITER_API_KEY",
        "RAYDIUM_API_KEY",
        "TON_API_KEY",
        "TAO_SUBNET_KEY",
        "HELIX_CHAIN_BRIDGE_KEY",
        "ZEC_SHIELDED_KEY",
        "ERC4337_BUNDLER_KEY",
        "FAILOVER_RPC_LIST",
      ]
    }
  }
}

resource "vault_mount" "cloud" {
  path        = local.cloud_mount_path
  type        = "kv-v2"
  description = "Cloud provider credentials consumed by Terraform modules."

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_mount" "rpc" {
  path        = local.rpc_mount_path
  type        = "kv-v2"
  description = "RPC endpoints and chain access tokens."

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_mount" "apps" {
  path        = local.apps_mount_path
  type        = "kv-v2"
  description = "Runtime application secrets fetched by containers at startup."

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_mount" "transit" {
  path        = local.transit_mount_path
  type        = "transit"
  description = "Optional envelope encryption for future signing or data protection flows."

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = "approle"
  description = "Machine authentication for Terraform and Akash workloads."

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_policy" "terraform_readonly" {
  name = "yieldswarm-terraform-readonly"
  policy = <<-EOT
    path "${vault_mount.cloud.path}/data/*" {
      capabilities = ["read"]
    }

    path "${vault_mount.cloud.path}/metadata/*" {
      capabilities = ["read", "list"]
    }

    path "${vault_mount.rpc.path}/data/*" {
      capabilities = ["read"]
    }

    path "${vault_mount.rpc.path}/metadata/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "akash_runtime" {
  name = "yieldswarm-akash-runtime"
  policy = <<-EOT
    path "${vault_mount.apps.path}/data/yieldswarm/*" {
      capabilities = ["read"]
    }

    path "${vault_mount.apps.path}/metadata/yieldswarm/*" {
      capabilities = ["read", "list"]
    }

    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend               = vault_auth_backend.approle.path
  role_name             = "yieldswarm-terraform"
  token_policies        = [vault_policy.terraform_readonly.name]
  token_ttl             = 1200
  token_max_ttl         = 3600
  token_bound_cidrs     = var.terraform_token_bound_cidrs
  bind_secret_id        = true
  secret_id_num_uses    = 1
  secret_id_ttl         = 1800
  secret_id_bound_cidrs = var.terraform_token_bound_cidrs
}

resource "vault_approle_auth_backend_role" "akash" {
  backend               = vault_auth_backend.approle.path
  role_name             = "yieldswarm-akash"
  token_policies        = [vault_policy.akash_runtime.name]
  token_ttl             = 900
  token_max_ttl         = 1800
  token_bound_cidrs     = var.akash_token_bound_cidrs
  bind_secret_id        = true
  secret_id_num_uses    = 1
  secret_id_ttl         = 900
  secret_id_bound_cidrs = var.akash_token_bound_cidrs
}

data "vault_kv_secret_v2" "azure" {
  count = var.enable_secret_contract_validation ? 1 : 0
  mount = vault_mount.cloud.path
  name  = local.secret_contracts.azure.name
}

data "vault_kv_secret_v2" "runpod" {
  count = var.enable_secret_contract_validation ? 1 : 0
  mount = vault_mount.cloud.path
  name  = local.secret_contracts.runpod.name
}

data "vault_kv_secret_v2" "vultr" {
  count = var.enable_secret_contract_validation ? 1 : 0
  mount = vault_mount.cloud.path
  name  = local.secret_contracts.vultr.name
}

data "vault_kv_secret_v2" "digitalocean" {
  count = var.enable_secret_contract_validation ? 1 : 0
  mount = vault_mount.cloud.path
  name  = local.secret_contracts.digitalocean.name
}

data "vault_kv_secret_v2" "rpc" {
  count = var.enable_secret_contract_validation ? 1 : 0
  mount = vault_mount.rpc.path
  name  = local.secret_contracts.rpc.name
}

locals {
  azure_secret        = var.enable_secret_contract_validation ? data.vault_kv_secret_v2.azure[0].data : {}
  runpod_secret       = var.enable_secret_contract_validation ? data.vault_kv_secret_v2.runpod[0].data : {}
  vultr_secret        = var.enable_secret_contract_validation ? data.vault_kv_secret_v2.vultr[0].data : {}
  digitalocean_secret = var.enable_secret_contract_validation ? data.vault_kv_secret_v2.digitalocean[0].data : {}
  rpc_secret          = var.enable_secret_contract_validation ? data.vault_kv_secret_v2.rpc[0].data : {}
}

check "azure_secret_contract" {
  assert {
    condition = !var.enable_secret_contract_validation || length(
      setsubtract(toset(local.secret_contracts.azure.required_fields), toset(keys(local.azure_secret)))
    ) == 0
    error_message = "Vault secret cloud/azure is missing one or more required Azure fields."
  }
}

check "runpod_secret_contract" {
  assert {
    condition = !var.enable_secret_contract_validation || length(
      setsubtract(toset(local.secret_contracts.runpod.required_fields), toset(keys(local.runpod_secret)))
    ) == 0
    error_message = "Vault secret cloud/runpod is missing api_key."
  }
}

check "vultr_secret_contract" {
  assert {
    condition = !var.enable_secret_contract_validation || length(
      setsubtract(toset(local.secret_contracts.vultr.required_fields), toset(keys(local.vultr_secret)))
    ) == 0
    error_message = "Vault secret cloud/vultr is missing api_key."
  }
}

check "digitalocean_secret_contract" {
  assert {
    condition = !var.enable_secret_contract_validation || length(
      setsubtract(toset(local.secret_contracts.digitalocean.required_fields), toset(keys(local.digitalocean_secret)))
    ) == 0
    error_message = "Vault secret cloud/digitalocean is missing token."
  }
}

check "rpc_secret_contract" {
  assert {
    condition = !var.enable_secret_contract_validation || length(
      setsubtract(toset(local.secret_contracts.rpc.required_fields), toset(keys(local.rpc_secret)))
    ) == 0
    error_message = "Vault secret rpc/mainnet is missing one or more required RPC fields."
  }
}
