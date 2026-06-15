provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

resource "vault_mount" "platform_kv" {
  path        = var.kv_mount_path
  type        = "kv-v2"
  description = "Platform and runtime credentials for infrastructure automation."
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = var.approle_path
}

resource "vault_policy" "terraform_read" {
  name   = "terraform-read-cloud-secrets"
  policy = templatefile("${path.module}/policies/terraform-read.hcl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_policy" "akash_runtime_read" {
  name   = "akash-runtime-read-secrets"
  policy = templatefile("${path.module}/policies/akash-runtime-read.hcl", { kv_mount_path = var.kv_mount_path })
}

resource "vault_approle_auth_backend_role" "terraform_reader" {
  backend        = vault_auth_backend.approle.path
  role_name      = var.terraform_role_name
  token_policies = [vault_policy.terraform_read.name]

  bind_secret_id = true
  secret_id_ttl  = 1800
  token_ttl      = 1200
  token_max_ttl  = 7200
  token_num_uses = 0
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend        = vault_auth_backend.approle.path
  role_name      = var.akash_role_name
  token_policies = [vault_policy.akash_runtime_read.name]

  bind_secret_id       = true
  secret_id_ttl        = 900
  token_ttl            = 900
  token_max_ttl        = 3600
  token_num_uses       = 0
  token_bound_cidrs    = var.akash_token_bound_cidrs
  secret_id_num_uses   = 1
}
