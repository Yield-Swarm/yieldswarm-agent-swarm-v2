output "kv_mount_path" {
  description = "KV v2 mount path for provider and application secrets."
  value       = vault_mount.kvv2.path
}

output "transit_mount_path" {
  description = "Transit mount path for application-side cryptography."
  value       = vault_mount.transit.path
}

output "approle_auth_path" {
  description = "AppRole auth mount path."
  value       = vault_auth_backend.approle.path
}

output "terraform_role_name" {
  description = "Terraform AppRole name."
  value       = vault_approle_auth_backend_role.terraform.role_name
}

output "terraform_role_id" {
  description = "Terraform AppRole RoleID."
  value       = data.vault_approle_auth_backend_role_id.terraform.role_id
}

output "openclaw_role_name" {
  description = "OpenClaw AppRole name."
  value       = vault_approle_auth_backend_role.openclaw.role_name
}

output "openclaw_role_id" {
  description = "OpenClaw AppRole RoleID."
  value       = data.vault_approle_auth_backend_role_id.openclaw.role_id
}

output "openclaw_secret_path" {
  description = "KV v2 secret path consumed by OpenClaw at runtime."
  value       = var.openclaw_secret_path
}
