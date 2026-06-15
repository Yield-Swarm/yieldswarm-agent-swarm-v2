output "kv_mount_path" {
  description = "KV v2 mount path for YieldSwarm secrets."
  value       = vault_mount.yieldswarm.path
}

output "terraform_policy_name" {
  description = "Policy to attach to Terraform Vault tokens."
  value       = vault_policy.terraform_read.name
}

output "secret_operator_policy_name" {
  description = "Policy to attach to operators that write or rotate secrets."
  value       = vault_policy.secret_operator.name
}

output "akash_policy_name" {
  description = "Runtime read-only policy attached to the Akash AppRole."
  value       = vault_policy.akash_runtime.name
}

output "akash_role_name" {
  description = "AppRole role name used by Akash workloads."
  value       = vault_approle_auth_backend_role.akash_runtime.role_name
}

output "akash_role_id_command" {
  description = "Command that prints the non-secret AppRole role ID for Akash deployments."
  value       = "vault read -field=role_id auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.akash_runtime.role_name}/role-id"
}

output "akash_wrapped_secret_id_command" {
  description = "Command that prints a short-lived wrapped secret ID token for a single Akash deployment."
  value       = "vault write -f -wrap-ttl=10m -field=wrapping_token auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.akash_runtime.role_name}/secret-id"
}
