output "provider_secrets" {
  description = "Vault-sourced cloud and RPC credentials for downstream modules."
  value       = local.provider_secrets
  sensitive   = true
}

output "secret_paths" {
  description = "Vault KV v2 paths read by this Terraform configuration."
  value = {
    azure        = "${var.kv_mount_path}/${var.azure_secret_path}"
    runpod       = "${var.kv_mount_path}/${var.runpod_secret_path}"
    vultr        = "${var.kv_mount_path}/${var.vultr_secret_path}"
    digitalocean = "${var.kv_mount_path}/${var.digitalocean_secret_path}"
    rpc          = "${var.kv_mount_path}/${var.rpc_secret_path}"
  }
}
