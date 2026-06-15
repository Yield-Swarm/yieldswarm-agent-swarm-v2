output "kv_mount" {
  description = "KV v2 mount containing YieldSwarm secrets."
  value       = vault_mount.kv.path
}

output "transit_mount" {
  description = "Transit mount containing YieldSwarm deployment keys."
  value       = vault_mount.transit.path
}

output "akash_runtime_role_name" {
  description = "AppRole role name used by Akash workloads."
  value       = vault_approle_auth_backend_role.akash_runtime.role_name
}

output "akash_runtime_role_id" {
  description = "Non-secret AppRole role ID used by Akash workloads."
  value       = vault_approle_auth_backend_role.akash_runtime.role_id
}

output "terraform_role_name" {
  description = "AppRole role name used by Terraform automation."
  value       = vault_approle_auth_backend_role.terraform.role_name
}

output "terraform_role_id" {
  description = "Non-secret AppRole role ID used by Terraform automation."
  value       = vault_approle_auth_backend_role.terraform.role_id
}

output "secret_paths" {
  description = "Canonical Vault KV v2 paths consumed by Terraform and Akash runtime."
  value = {
    azure        = "${vault_mount.kv.path}/cloud/azure"
    runpod       = "${vault_mount.kv.path}/cloud/runpod"
    vultr        = "${vault_mount.kv.path}/cloud/vultr"
    digitalocean = "${vault_mount.kv.path}/cloud/digitalocean"
    rpc_mainnet  = "${vault_mount.kv.path}/rpc/mainnet"
    app_runtime  = "${vault_mount.kv.path}/app/agentswarm"
  }
}
