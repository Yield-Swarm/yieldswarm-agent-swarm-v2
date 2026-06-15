output "kv_mount_path" {
  description = "KVv2 mount path for platform credentials."
  value       = vault_mount.platform_kv.path
}

output "approle_path" {
  description = "AppRole auth path."
  value       = vault_auth_backend.approle.path
}

output "terraform_role_name" {
  description = "Terraform AppRole name."
  value       = vault_approle_auth_backend_role.terraform_reader.role_name
}

output "akash_role_name" {
  description = "Akash runtime AppRole name."
  value       = vault_approle_auth_backend_role.akash_runtime.role_name
}
