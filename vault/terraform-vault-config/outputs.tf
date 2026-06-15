output "kv_mount" {
  description = "KVv2 mount path for application secrets."
  value       = vault_mount.yieldswarm.path
}

output "transit_mount" {
  description = "Transit mount path for envelope encryption."
  value       = vault_mount.transit.path
}

output "approle_role_ids" {
  description = "Role IDs for each AppRole. These are not secret on their own (a wrapped SecretID is still required to login)."
  value = {
    terraform     = vault_approle_auth_backend_role.terraform.role_id
    akash_runtime = vault_approle_auth_backend_role.akash_runtime.role_id
    agent_runtime = vault_approle_auth_backend_role.agent_runtime.role_id
    ci_bootstrap  = vault_approle_auth_backend_role.ci_bootstrap.role_id
  }
}

output "policies" {
  description = "Names of all managed policies."
  value       = keys(local.policies)
}
