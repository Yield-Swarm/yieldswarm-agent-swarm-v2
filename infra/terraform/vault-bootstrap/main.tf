locals {
  kv_mount_path          = trim(var.kv_mount_path, "/")
  transit_mount_path     = trim(var.transit_mount_path, "/")
  approle_mount_path     = trim(var.approle_mount_path, "/")
  provider_secret_paths  = values(var.provider_secret_paths)
  rpc_secret_path        = trim(var.rpc_secret_path, "/")
  akash_runtime_path     = trim(var.akash_runtime_secret_path, "/")
  akash_transit_key_name = "akash-runtime"
}

resource "vault_mount" "kv" {
  path        = local.kv_mount_path
  type        = "kv"
  description = "KV v2 secrets engine for platform provider and runtime secrets"

  options = {
    version = "2"
  }
}

resource "vault_mount" "transit" {
  path        = local.transit_mount_path
  type        = "transit"
  description = "Transit engine for Akash runtime envelope encryption"
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = local.approle_mount_path
  description = "Machine authentication for Terraform and Akash workloads"
}

resource "vault_transit_secret_backend_key" "akash_runtime" {
  backend                = vault_mount.transit.path
  name                   = local.akash_transit_key_name
  deletion_allowed       = false
  exportable             = false
  allow_plaintext_backup = false
}

resource "vault_policy" "terraform_platform" {
  name = var.terraform_policy_name
  policy = templatefile("${path.module}/policies/terraform-platform.hcl.tftpl", {
    kv_mount_path         = local.kv_mount_path
    provider_secret_paths = local.provider_secret_paths
    rpc_secret_path       = local.rpc_secret_path
  })
}

resource "vault_policy" "akash_runtime" {
  name = var.akash_policy_name
  policy = templatefile("${path.module}/policies/akash-runtime.hcl.tftpl", {
    kv_mount_path      = local.kv_mount_path
    akash_runtime_path = local.akash_runtime_path
    transit_mount_path = local.transit_mount_path
    transit_key_name   = vault_transit_secret_backend_key.akash_runtime.name
  })
}

resource "vault_approle_auth_backend_role" "terraform_platform" {
  backend                 = vault_auth_backend.approle.path
  role_name               = var.terraform_role_name
  token_policies          = [vault_policy.terraform_platform.name]
  bind_secret_id          = true
  token_type              = "service"
  token_ttl               = var.terraform_token_ttl_seconds
  token_max_ttl           = var.terraform_token_max_ttl_seconds
  token_num_uses          = 0
  token_no_default_policy = true
  secret_id_ttl           = var.terraform_secret_id_ttl_seconds
  secret_id_num_uses      = var.terraform_secret_id_num_uses
  token_bound_cidrs       = length(var.terraform_token_bound_cidrs) > 0 ? var.terraform_token_bound_cidrs : null
  secret_id_bound_cidrs   = length(var.terraform_secret_id_bound_cidrs) > 0 ? var.terraform_secret_id_bound_cidrs : null
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend                 = vault_auth_backend.approle.path
  role_name               = var.akash_role_name
  token_policies          = [vault_policy.akash_runtime.name]
  bind_secret_id          = true
  token_type              = "service"
  token_ttl               = var.akash_token_ttl_seconds
  token_max_ttl           = var.akash_token_max_ttl_seconds
  token_num_uses          = 0
  token_no_default_policy = true
  secret_id_ttl           = var.akash_secret_id_ttl_seconds
  secret_id_num_uses      = var.akash_secret_id_num_uses
  token_bound_cidrs       = length(var.akash_token_bound_cidrs) > 0 ? var.akash_token_bound_cidrs : null
  secret_id_bound_cidrs   = length(var.akash_secret_id_bound_cidrs) > 0 ? var.akash_secret_id_bound_cidrs : null
}

output "vault_contract" {
  description = "Non-sensitive mount paths, policy names, and secret contract paths."
  value = {
    mounts = {
      kv      = vault_mount.kv.path
      transit = vault_mount.transit.path
      approle = vault_auth_backend.approle.path
    }
    policies = {
      terraform = vault_policy.terraform_platform.name
      akash     = vault_policy.akash_runtime.name
    }
    approles = {
      terraform = vault_approle_auth_backend_role.terraform_platform.role_name
      akash     = vault_approle_auth_backend_role.akash_runtime.role_name
    }
    secret_paths = {
      azure         = "${vault_mount.kv.path}/data/${var.provider_secret_paths.azure}"
      runpod        = "${vault_mount.kv.path}/data/${var.provider_secret_paths.runpod}"
      vultr         = "${vault_mount.kv.path}/data/${var.provider_secret_paths.vultr}"
      digitalocean  = "${vault_mount.kv.path}/data/${var.provider_secret_paths.digitalocean}"
      rpc           = "${vault_mount.kv.path}/data/${var.rpc_secret_path}"
      akash_runtime = "${vault_mount.kv.path}/data/${var.akash_runtime_secret_path}"
      akash_transit = "${vault_mount.transit.path}/keys/${vault_transit_secret_backend_key.akash_runtime.name}"
    }
  }
}
