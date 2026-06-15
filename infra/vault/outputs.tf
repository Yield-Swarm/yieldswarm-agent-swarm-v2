output "kv_mount_path" {
  description = "KV v2 mount path that stores provider and runtime secrets."
  value       = vault_mount.kv.path
}

output "transit_mount_path" {
  description = "Transit mount path for runtime cryptographic operations."
  value       = vault_mount.transit.path
}

output "terraform_approle_role_name" {
  description = "AppRole name Terraform automation should use."
  value       = vault_approle_auth_backend_role.terraform.role_name
}

output "akash_runtime_approle_role_name" {
  description = "AppRole name Akash workloads should use."
  value       = vault_approle_auth_backend_role.akash_runtime.role_name
}

output "terraform_policy_name" {
  description = "Vault policy attached to Terraform automation tokens."
  value       = vault_policy.terraform_secrets_read.name
}

output "akash_runtime_policy_name" {
  description = "Vault policy attached to Akash runtime tokens."
  value       = vault_policy.akash_runtime.name
}
