provider "vault" {
  address          = var.vault_addr
  namespace        = try(length(var.vault_namespace), 0) > 0 ? var.vault_namespace : null
  skip_child_token = true
}

locals {
  terraform_policy = templatefile("${path.module}/policies/terraform-secrets-read.hcl.tftpl", {
    kv_mount_path = vault_mount.kv.path
    secret_paths  = var.terraform_secret_paths
  })

  akash_runtime_policy = templatefile("${path.module}/policies/akash-runtime.hcl.tftpl", {
    kv_mount_path      = vault_mount.kv.path
    transit_mount_path = vault_mount.transit.path
    secret_paths       = var.akash_runtime_secret_paths
  })
}

resource "vault_mount" "kv" {
  path        = var.kv_mount_path
  type        = "kv-v2"
  description = "YieldSwarm provider and runtime secrets"

  options = {
    version = "2"
  }
}

resource "vault_mount" "transit" {
  path        = var.transit_mount_path
  type        = "transit"
  description = "YieldSwarm runtime encryption keys"
}

resource "vault_transit_secret_backend_key" "akash_runtime_env" {
  backend          = vault_mount.transit.path
  name             = "akash-runtime-env"
  type             = "aes256-gcm96"
  deletion_allowed = false
  exportable       = false
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  description = "AppRole auth for Terraform automation and Akash workloads"
}

resource "vault_policy" "terraform_secrets_read" {
  name   = "terraform-secrets-read"
  policy = local.terraform_policy
}

resource "vault_policy" "akash_runtime" {
  name   = "akash-runtime"
  policy = local.akash_runtime_policy
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend        = vault_auth_backend.approle.path
  role_name      = "terraform"
  token_policies = [vault_policy.terraform_secrets_read.name]

  bind_secret_id         = true
  secret_id_num_uses     = 1
  secret_id_ttl          = 1800
  token_ttl              = 3600
  token_max_ttl          = 14400
  token_explicit_max_ttl = 14400
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend        = vault_auth_backend.approle.path
  role_name      = "akash-runtime"
  token_policies = [vault_policy.akash_runtime.name]

  bind_secret_id         = true
  secret_id_num_uses     = 1
  secret_id_ttl          = 600
  token_ttl              = 3600
  token_max_ttl          = 86400
  token_explicit_max_ttl = 86400
}
