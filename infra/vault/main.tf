locals {
  kv_mount_path       = trimsuffix(var.kv_mount_path, "/")
  transit_mount_path  = trimsuffix(var.transit_mount_path, "/")
  approle_mount_path  = trimsuffix(var.approle_mount_path, "/")
  provider_secret_set = ["azure", "runpod", "vultr", "digitalocean", "rpc"]
}

provider "vault" {}

resource "vault_mount" "platform_kv" {
  path        = local.kv_mount_path
  type        = "kv"
  description = "YieldSwarm platform secrets. Values are written with the Vault CLI only."

  options = {
    version = "2"
  }
}

resource "vault_mount" "runtime_transit" {
  path        = local.transit_mount_path
  type        = "transit"
  description = "YieldSwarm runtime transit keys."
}

resource "vault_transit_secret_backend_key" "akash_env" {
  backend = vault_mount.runtime_transit.path
  name    = "akash-env"

  deletion_allowed       = false
  exportable             = false
  allow_plaintext_backup = false
}

resource "vault_auth_backend" "approle" {
  path        = local.approle_mount_path
  type        = "approle"
  description = "AppRole auth for non-human YieldSwarm automation."
}

resource "vault_policy" "terraform_platform" {
  name = "yieldswarm-terraform-platform"

  policy = templatefile("${path.module}/policies/terraform-platform.hcl.tftpl", {
    kv_mount_path      = vault_mount.platform_kv.path
    provider_secrets   = local.provider_secret_set
    approle_mount_path = vault_auth_backend.approle.path
  })
}

resource "vault_policy" "akash_runtime" {
  name = "yieldswarm-akash-runtime"

  policy = templatefile("${path.module}/policies/akash-runtime.hcl.tftpl", {
    kv_mount_path      = vault_mount.platform_kv.path
    transit_mount_path = vault_mount.runtime_transit.path
  })
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend   = vault_auth_backend.approle.path
  role_name = "yieldswarm-terraform"

  token_policies     = [vault_policy.terraform_platform.name]
  token_ttl          = 1800
  token_max_ttl      = 3600
  token_num_uses     = 0
  secret_id_ttl      = 900
  secret_id_num_uses = 1
  bind_secret_id     = true
  token_bound_cidrs  = var.terraform_token_bound_cidrs
}

resource "vault_approle_auth_backend_role" "akash" {
  backend   = vault_auth_backend.approle.path
  role_name = "yieldswarm-akash"

  token_policies     = [vault_policy.akash_runtime.name]
  token_ttl          = 900
  token_max_ttl      = 1800
  token_num_uses     = 0
  secret_id_ttl      = 300
  secret_id_num_uses = 1
  bind_secret_id     = true
  token_bound_cidrs  = var.akash_token_bound_cidrs
}
