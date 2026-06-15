output "kv_mount_path" {
  description = "KV v2 mount path for YieldSwarm secrets."
  value       = vault_mount.kv.path
}

output "transit_mount_path" {
  description = "Transit mount path for YieldSwarm encryption keys."
  value       = vault_mount.transit.path
}

output "policy_names" {
  description = "Vault policies managed by this bootstrap."
  value       = { for key, policy in vault_policy.this : key => policy.name }
}

output "approle_role_id_commands" {
  description = "Commands for operators to read non-secret AppRole role IDs."
  value = {
    akash_runtime           = "vault read -field=role_id auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.akash_runtime.role_name}/role-id"
    chainlink_vault_manager = "vault read -field=role_id auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.chainlink_vault_manager.role_name}/role-id"
    openclaw_scaler         = "vault read -field=role_id auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.openclaw_scaler.role_name}/role-id"
    terraform_ci            = "vault read -field=role_id auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.terraform_ci.role_name}/role-id"
  }
}

output "wrapped_secret_id_commands" {
  description = "Commands for operators to issue one-use wrapped SecretIDs."
  value = {
    akash_runtime           = "vault write -wrap-ttl=10m -field=wrapping_token -f auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.akash_runtime.role_name}/secret-id"
    chainlink_vault_manager = "vault write -wrap-ttl=10m -field=wrapping_token -f auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.chainlink_vault_manager.role_name}/secret-id"
    openclaw_scaler         = "vault write -wrap-ttl=10m -field=wrapping_token -f auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.openclaw_scaler.role_name}/secret-id"
    terraform_ci            = "vault write -wrap-ttl=10m -field=wrapping_token -f auth/${vault_auth_backend.approle.path}/role/${vault_approle_auth_backend_role.terraform_ci.role_name}/secret-id"
  }
  sensitive = true
}
