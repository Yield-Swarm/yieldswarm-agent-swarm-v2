output "vault_secret_paths" {
  description = "Vault KV paths consumed by Terraform and Akash."
  value = {
    azure        = "${var.cloud_mount_path}/azure"
    runpod       = "${var.cloud_mount_path}/runpod"
    vultr        = "${var.cloud_mount_path}/vultr"
    digitalocean = "${var.cloud_mount_path}/digitalocean"
    rpc          = "${var.rpc_mount_path}/rpc"
  }
}

output "terraform_approle_name" {
  description = "AppRole name to issue Terraform role_id and secret_id."
  value       = vault_approle_auth_backend_role.terraform_ci.role_name
}

output "akash_kubernetes_role_name" {
  description = "Kubernetes auth role used by the Akash runtime."
  value       = vault_kubernetes_auth_backend_role.akash_runtime.role_name
}

output "terraform_loaded_credentials" {
  description = "Secret object loaded from Vault for Terraform consumers."
  value = {
    enabled      = var.read_runtime_secrets
    azure        = local.azure_credentials
    runpod       = local.runpod_credentials
    vultr        = local.vultr_credentials
    digitalocean = local.digitalocean_credentials
    rpc          = local.rpc_credentials
  }
  sensitive = true
}
