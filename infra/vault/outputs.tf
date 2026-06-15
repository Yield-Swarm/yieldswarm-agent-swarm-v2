output "kv_mount_path" {
  description = "KV v2 mount that stores platform secrets."
  value       = vault_mount.platform_kv.path
}

output "transit_mount_path" {
  description = "Transit mount that stores runtime cryptographic keys."
  value       = vault_mount.runtime_transit.path
}

output "approle_mount_path" {
  description = "AppRole auth mount for automation identities."
  value       = vault_auth_backend.approle.path
}

output "terraform_approle_name" {
  description = "AppRole name used by Terraform automation."
  value       = vault_approle_auth_backend_role.terraform.role_name
}

output "akash_approle_name" {
  description = "AppRole name used by Akash runtime workloads."
  value       = vault_approle_auth_backend_role.akash.role_name
}

output "required_secret_paths" {
  description = "KV v2 paths that must be populated with vault kv put before planning deployments."
  value = {
    azure        = "${vault_mount.platform_kv.path}/azure"
    runpod       = "${vault_mount.platform_kv.path}/runpod"
    vultr        = "${vault_mount.platform_kv.path}/vultr"
    digitalocean = "${vault_mount.platform_kv.path}/digitalocean"
    rpc          = "${vault_mount.platform_kv.path}/rpc"
    akash        = "${vault_mount.platform_kv.path}/akash/runtime"
  }
}
