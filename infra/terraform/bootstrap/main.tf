provider "vault" {
  skip_child_token = true
}

resource "vault_mount" "platform" {
  path        = var.platform_mount_path
  type        = "kv-v2"
  description = "Cloud provider and RPC credentials for ${var.application_name}"
  options = {
    version = "2"
  }
}

resource "vault_mount" "runtime" {
  path        = var.runtime_mount_path
  type        = "kv-v2"
  description = "Runtime application secrets for ${var.application_name}"
  options = {
    version = "2"
  }
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = var.approle_path
}

resource "vault_policy" "terraform" {
  name = var.terraform_role_name
  policy = templatefile("${path.module}/../../vault/policies/terraform.hcl", {
    application_name = var.application_name
    environment      = var.environment
    platform_mount   = vault_mount.platform.path
    runtime_mount    = vault_mount.runtime.path
  })
}

resource "vault_policy" "akash_runtime" {
  name = var.akash_role_name
  policy = templatefile("${path.module}/../../vault/policies/akash-runtime.hcl", {
    application_name = var.application_name
    environment      = var.environment
    runtime_mount    = vault_mount.runtime.path
  })
}

resource "vault_approle_auth_backend_role" "terraform" {
  backend                 = vault_auth_backend.approle.path
  role_name               = var.terraform_role_name
  bind_secret_id          = true
  secret_id_num_uses      = var.terraform_secret_id_num_uses
  secret_id_ttl           = var.terraform_secret_id_ttl
  secret_id_bound_cidrs   = var.terraform_secret_id_bound_cidrs
  token_bound_cidrs       = var.terraform_token_bound_cidrs
  token_no_default_policy = true
  token_policies          = [vault_policy.terraform.name]
  token_ttl               = var.terraform_token_ttl
  token_max_ttl           = var.terraform_token_max_ttl
}

resource "vault_approle_auth_backend_role" "akash_runtime" {
  backend                 = vault_auth_backend.approle.path
  role_name               = var.akash_role_name
  bind_secret_id          = true
  secret_id_num_uses      = var.akash_secret_id_num_uses
  secret_id_ttl           = var.akash_secret_id_ttl
  secret_id_bound_cidrs   = var.akash_secret_id_bound_cidrs
  token_bound_cidrs       = var.akash_token_bound_cidrs
  token_no_default_policy = true
  token_policies          = [vault_policy.akash_runtime.name]
  token_ttl               = var.akash_token_ttl
  token_max_ttl           = var.akash_token_max_ttl
}

output "vault_mounts" {
  description = "KV mounts created by this stack."
  value = {
    platform = vault_mount.platform.path
    runtime  = vault_mount.runtime.path
  }
}

output "approle_paths" {
  description = "AppRole paths to use when reading role IDs and creating SecretIDs."
  value = {
    terraform_role = "auth/${vault_auth_backend.approle.path}/role/${var.terraform_role_name}"
    akash_role     = "auth/${vault_auth_backend.approle.path}/role/${var.akash_role_name}"
  }
}
