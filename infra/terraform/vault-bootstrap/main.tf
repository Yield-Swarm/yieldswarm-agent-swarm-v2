locals {
  policy_files = {
    akash-runtime            = "${path.module}/../../../vault/policies/akash-runtime.hcl"
    chainlink-vault-manager  = "${path.module}/../../../vault/policies/chainlink-vault-manager.hcl"
    openclaw-scaler          = "${path.module}/../../../vault/policies/openclaw-scaler.hcl"
    terraform-ci             = "${path.module}/../../../vault/policies/terraform-ci.hcl"
  }

  policy_names = {
    for name, _ in local.policy_files : name => "${var.policy_prefix}-${name}"
  }
}

resource "vault_mount" "kv" {
  path        = var.kv_mount_path
  type        = "kv"
  description = "YieldSwarm production KV v2 secrets"

  options = {
    version = "2"
  }
}

resource "vault_mount" "transit" {
  path        = var.transit_mount_path
  type        = "transit"
  description = "YieldSwarm envelope encryption"
}

resource "vault_transit_secret_backend_key" "wallet" {
  backend          = vault_mount.transit.path
  name             = "yieldswarm-wallet"
  deletion_allowed = false
  exportable       = false
}

resource "vault_transit_secret_backend_key" "database" {
  backend          = vault_mount.transit.path
  name             = "yieldswarm-database"
  deletion_allowed = false
  exportable       = false
}

resource "vault_policy" "this" {
  for_each = local.policy_files

  name   = local.policy_names[each.key]
  policy = file(each.value)

  depends_on = [vault_mount.kv, vault_mount.transit]
}

resource "vault_auth_backend" "approle" {
  type        = "approle"
  path        = var.approle_mount_path
  description = "YieldSwarm non-human workload authentication"
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend        = vault_auth_backend.approle.path
  role_name      = "yieldswarm-akash-runtime"
  token_policies = [vault_policy.this["akash-runtime"].name]

  bind_secret_id         = true
  local_secret_ids       = true
  secret_id_num_uses     = 1
  secret_id_ttl          = "30m"
  token_ttl              = var.runtime_token_ttl
  token_max_ttl          = var.runtime_token_max_ttl
  token_num_uses         = 0
  token_period           = var.runtime_token_ttl
  token_bound_cidrs      = []
  secret_id_bound_cidrs  = []
}

resource "vault_approle_auth_backend_role" "chainlink_vault_manager" {
  backend        = vault_auth_backend.approle.path
  role_name      = "yieldswarm-chainlink-vault-manager"
  token_policies = [vault_policy.this["chainlink-vault-manager"].name]

  bind_secret_id     = true
  local_secret_ids   = true
  secret_id_num_uses = 1
  secret_id_ttl      = "30m"
  token_ttl          = var.runtime_token_ttl
  token_max_ttl      = var.runtime_token_max_ttl
  token_num_uses     = 0
  token_period       = var.runtime_token_ttl
}

resource "vault_approle_auth_backend_role" "openclaw_scaler" {
  backend        = vault_auth_backend.approle.path
  role_name      = "yieldswarm-openclaw-scaler"
  token_policies = [vault_policy.this["openclaw-scaler"].name]

  bind_secret_id     = true
  local_secret_ids   = true
  secret_id_num_uses = 1
  secret_id_ttl      = "30m"
  token_ttl          = var.runtime_token_ttl
  token_max_ttl      = var.runtime_token_max_ttl
  token_num_uses     = 0
  token_period       = var.runtime_token_ttl
}

resource "vault_approle_auth_backend_role" "terraform_ci" {
  backend        = vault_auth_backend.approle.path
  role_name      = "yieldswarm-terraform-ci"
  token_policies = [vault_policy.this["terraform-ci"].name]

  bind_secret_id     = true
  local_secret_ids   = true
  secret_id_num_uses = 1
  secret_id_ttl      = "15m"
  token_ttl          = var.terraform_token_ttl
  token_max_ttl      = var.terraform_token_max_ttl
  token_num_uses     = 0
}
