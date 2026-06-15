output "runtime_policy_name" {
  description = "Vault policy attached to Odysseus runtime identities."
  value       = vault_policy.odysseus_runtime.name
}

output "deploy_policy_name" {
  description = "Vault policy attached to CI and production deploy identities."
  value       = vault_policy.odysseus_deploy.name
}

output "runtime_secret_path" {
  description = "Vault KV path read by the Odysseus container entrypoint."
  value       = var.runtime_secret_path
}

output "deploy_secret_path" {
  description = "Vault KV path read by CI and production deployment scripts."
  value       = var.deploy_secret_path
}
