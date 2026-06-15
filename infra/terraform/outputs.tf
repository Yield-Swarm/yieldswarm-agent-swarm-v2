output "vault_secret_paths" {
  description = "Vault paths read by this Terraform stack. Values are intentionally not exposed."
  value = {
    azure        = "${local.vault_kv_mount_path}/${var.azure_secret_path}"
    runpod       = "${local.vault_kv_mount_path}/${var.runpod_secret_path}"
    vultr        = "${local.vault_kv_mount_path}/${var.vultr_secret_path}"
    digitalocean = "${local.vault_kv_mount_path}/${var.digitalocean_secret_path}"
    rpc          = "${local.vault_kv_mount_path}/${var.rpc_secret_path}"
  }
}

output "rpc_secret_keys" {
  description = "RPC keys present in Vault. Secret values stay in Vault/Terraform state and are not output."
  value       = keys(local.rpc)
}
