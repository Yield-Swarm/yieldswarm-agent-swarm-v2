provider "vault" {
  address          = var.vault_addr
  token            = var.vault_token
  namespace        = var.vault_namespace
  skip_child_token = true
}

resource "vault_mount" "kv_platform" {
  path        = var.kv_platform_mount_path
  type        = "kv"
  description = "KV v2 secrets for cloud provider and RPC credentials"
  options = {
    version = "2"
  }
}

resource "vault_kv_secret_backend_v2" "kv_platform" {
  mount                = vault_mount.kv_platform.path
  max_versions         = var.kv_max_versions
  cas_required         = true
  delete_version_after = var.kv_delete_version_after_seconds
}

resource "vault_mount" "kv_runtime" {
  path        = var.kv_runtime_mount_path
  type        = "kv"
  description = "KV v2 runtime secrets for application and Akash workloads"
  options = {
    version = "2"
  }
}

resource "vault_kv_secret_backend_v2" "kv_runtime" {
  mount                = vault_mount.kv_runtime.path
  max_versions         = var.kv_max_versions
  cas_required         = true
  delete_version_after = var.kv_delete_version_after_seconds
}

resource "vault_mount" "transit" {
  path        = var.transit_mount_path
  type        = "transit"
  description = "Transit secrets engine for envelope encryption and signing"
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = var.approle_path
}

locals {
  terraform_operator_policy = templatefile("${path.module}/templates/terraform-operator-policy.hcl.tftpl", {
    kv_platform_mount = vault_mount.kv_platform.path
    kv_runtime_mount  = vault_mount.kv_runtime.path
    transit_mount     = vault_mount.transit.path
    approle_path      = vault_auth_backend.approle.path
  })

  akash_runtime_policy = templatefile("${path.module}/templates/akash-runtime-policy.hcl.tftpl", {
    kv_platform_mount = vault_mount.kv_platform.path
    kv_runtime_mount  = vault_mount.kv_runtime.path
  })
}

resource "vault_policy" "terraform_operator" {
  name   = "terraform-operator"
  policy = local.terraform_operator_policy
}

resource "vault_policy" "akash_runtime" {
  name   = "akash-runtime"
  policy = local.akash_runtime_policy
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend             = vault_auth_backend.approle.path
  role_name           = var.akash_role_name
  token_policies      = [vault_policy.akash_runtime.name]
  token_ttl           = var.akash_token_ttl_seconds
  token_max_ttl       = var.akash_token_max_ttl_seconds
  secret_id_ttl       = var.akash_secret_id_ttl_seconds
  secret_id_num_uses  = var.akash_secret_id_num_uses
  secret_id_bound_cidrs = length(var.akash_secret_id_bound_cidrs) > 0 ? var.akash_secret_id_bound_cidrs : null
}

data "vault_kv_secret_v2" "azure" {
  count = var.enable_secret_reads ? 1 : 0

  mount = vault_mount.kv_platform.path
  name  = "providers/azure"

  depends_on = [vault_kv_secret_backend_v2.kv_platform]
}

data "vault_kv_secret_v2" "runpod" {
  count = var.enable_secret_reads ? 1 : 0

  mount = vault_mount.kv_platform.path
  name  = "providers/runpod"

  depends_on = [vault_kv_secret_backend_v2.kv_platform]
}

data "vault_kv_secret_v2" "vultr" {
  count = var.enable_secret_reads ? 1 : 0

  mount = vault_mount.kv_platform.path
  name  = "providers/vultr"

  depends_on = [vault_kv_secret_backend_v2.kv_platform]
}

data "vault_kv_secret_v2" "digitalocean" {
  count = var.enable_secret_reads ? 1 : 0

  mount = vault_mount.kv_platform.path
  name  = "providers/digitalocean"

  depends_on = [vault_kv_secret_backend_v2.kv_platform]
}

data "vault_kv_secret_v2" "rpc" {
  count = var.enable_secret_reads ? 1 : 0

  mount = vault_mount.kv_platform.path
  name  = "rpc/shared"

  depends_on = [vault_kv_secret_backend_v2.kv_platform]
}

locals {
  azure_secret        = var.enable_secret_reads ? data.vault_kv_secret_v2.azure[0].data : {}
  runpod_secret       = var.enable_secret_reads ? data.vault_kv_secret_v2.runpod[0].data : {}
  vultr_secret        = var.enable_secret_reads ? data.vault_kv_secret_v2.vultr[0].data : {}
  digitalocean_secret = var.enable_secret_reads ? data.vault_kv_secret_v2.digitalocean[0].data : {}
  rpc_secret          = var.enable_secret_reads ? data.vault_kv_secret_v2.rpc[0].data : {}

  terraform_provider_environment = var.enable_secret_reads ? merge(
    local.azure_secret,
    local.runpod_secret,
    local.vultr_secret,
    local.digitalocean_secret,
    local.rpc_secret,
  ) : {}
}

resource "terraform_data" "secret_contract" {
  count = var.enable_secret_reads ? 1 : 0
  input = local.terraform_provider_environment

  lifecycle {
    precondition {
      condition = alltrue([
        for key in [
          "ARM_SUBSCRIPTION_ID",
          "ARM_TENANT_ID",
          "ARM_CLIENT_ID",
          "ARM_CLIENT_SECRET",
        ] : trimspace(lookup(local.azure_secret, key, "")) != ""
      ])
      error_message = "Vault secret kv-platform/providers/azure must define ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, and ARM_CLIENT_SECRET."
    }

    precondition {
      condition     = trimspace(lookup(local.runpod_secret, "RUNPOD_API_KEY", "")) != ""
      error_message = "Vault secret kv-platform/providers/runpod must define RUNPOD_API_KEY."
    }

    precondition {
      condition     = trimspace(lookup(local.vultr_secret, "VULTR_API_KEY", "")) != ""
      error_message = "Vault secret kv-platform/providers/vultr must define VULTR_API_KEY."
    }

    precondition {
      condition     = trimspace(lookup(local.digitalocean_secret, "DIGITALOCEAN_TOKEN", "")) != ""
      error_message = "Vault secret kv-platform/providers/digitalocean must define DIGITALOCEAN_TOKEN."
    }

    precondition {
      condition = alltrue([
        for key in [
          "SOLANA_RPC_URL",
          "HELIUS_API_KEY",
        ] : trimspace(lookup(local.rpc_secret, key, "")) != ""
      ])
      error_message = "Vault secret kv-platform/rpc/shared must define SOLANA_RPC_URL and HELIUS_API_KEY."
    }

    precondition {
      condition     = can(jsondecode(lookup(local.rpc_secret, "FAILOVER_RPC_LIST", "[]")))
      error_message = "Vault secret kv-platform/rpc/shared FAILOVER_RPC_LIST must be valid JSON."
    }
  }
}
