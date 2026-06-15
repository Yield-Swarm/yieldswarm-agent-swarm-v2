locals {
  terraform_policy_name    = "${var.policy_prefix}-terraform"
  akash_runtime_policy_name = "${var.policy_prefix}-akash-runtime"
  secret_writer_policy_name = "${var.policy_prefix}-secret-writer"

  terraform_role_name    = "${var.policy_prefix}-terraform"
  akash_runtime_role_name = "${var.policy_prefix}-akash-runtime"
}

resource "vault_mount" "kv" {
  path        = var.kv_mount
  type        = "kv-v2"
  description = "YieldSwarm KV v2 secrets for cloud provider credentials, RPC endpoints, and runtime application secrets."
}

resource "vault_mount" "transit" {
  path        = var.transit_mount
  type        = "transit"
  description = "YieldSwarm transit keys for deployment-time envelope encryption."
}

resource "vault_transit_secret_backend_key" "akash_runtime" {
  backend                = vault_mount.transit.path
  name                   = var.transit_key_name
  deletion_allowed       = false
  exportable             = false
  allow_plaintext_backup = false
}

resource "vault_policy" "terraform" {
  name = local.terraform_policy_name

  policy = templatefile("${path.module}/policies/terraform.hcl.tpl", {
    kv_mount      = vault_mount.kv.path
    transit_mount = vault_mount.transit.path
  })
}

resource "vault_policy" "akash_runtime" {
  name = local.akash_runtime_policy_name

  policy = templatefile("${path.module}/policies/akash-runtime.hcl.tpl", {
    kv_mount      = vault_mount.kv.path
    transit_mount = vault_mount.transit.path
    transit_key   = vault_transit_secret_backend_key.akash_runtime.name
  })
}

resource "vault_policy" "secret_writer" {
  name = local.secret_writer_policy_name

  policy = templatefile("${path.module}/policies/secret-writer.hcl.tpl", {
    kv_mount = vault_mount.kv.path
  })
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = var.approle_mount
  description = "AppRole auth for YieldSwarm automation and Akash runtime workloads."
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend        = vault_auth_backend.approle.path
  role_name      = local.terraform_role_name
  bind_secret_id = true

  token_policies     = [vault_policy.terraform.name]
  token_ttl          = var.terraform_token_ttl
  token_max_ttl      = var.terraform_token_max_ttl
  token_bound_cidrs  = var.token_bound_cidrs
  secret_id_num_uses = 10
  secret_id_ttl      = "30m"
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend        = vault_auth_backend.approle.path
  role_name      = local.akash_runtime_role_name
  bind_secret_id = true

  token_policies     = [vault_policy.akash_runtime.name]
  token_ttl          = var.akash_token_ttl
  token_max_ttl      = var.akash_token_max_ttl
  token_bound_cidrs  = var.token_bound_cidrs
  secret_id_num_uses = 1
  secret_id_ttl      = "10m"
}
