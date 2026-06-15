output "vault_bootstrap" {
  description = "Non-secret bootstrap details for operators and CI/CD systems."
  value = {
    kv_platform_mount = vault_mount.kv_platform.path
    kv_runtime_mount  = vault_mount.kv_runtime.path
    transit_mount     = vault_mount.transit.path
    approle_path      = vault_auth_backend.approle.path
    terraform_policy  = vault_policy.terraform_operator.name
    akash_policy      = vault_policy.akash_runtime.name
    akash_role_name   = vault_approle_auth_backend_role.akash_runtime.role_name
  }
}

output "vault_secret_paths" {
  description = "Canonical Vault KV paths expected by this repository."
  value = {
    azure                    = "${vault_mount.kv_platform.path}/providers/azure"
    runpod                   = "${vault_mount.kv_platform.path}/providers/runpod"
    vultr                    = "${vault_mount.kv_platform.path}/providers/vultr"
    digitalocean             = "${vault_mount.kv_platform.path}/providers/digitalocean"
    rpc                      = "${vault_mount.kv_platform.path}/rpc/shared"
    akash_runtime            = "${vault_mount.kv_runtime.path}/akash/optimizer"
    application_common       = "${vault_mount.kv_runtime.path}/application/common"
  }
}

output "terraform_provider_environment" {
  description = "Sensitive environment variables exported from Vault for downstream Terraform providers."
  value       = local.terraform_provider_environment
  sensitive   = true
}
