output "vault_secret_sources" {
  description = "Vault paths used by Terraform."
  value = {
    azure        = "${var.vault_cloud_mount}/${var.azure_secret_name}"
    runpod       = "${var.vault_cloud_mount}/${var.runpod_secret_name}"
    vultr        = "${var.vault_cloud_mount}/${var.vultr_secret_name}"
    digitalocean = "${var.vault_cloud_mount}/${var.digitalocean_secret_name}"
    rpc          = "${var.vault_rpc_mount}/${var.rpc_secret_name}"
  }
}

output "rpc_primary_url" {
  description = "Primary RPC endpoint from Vault."
  value       = local.rpc_credentials["primary_url"]
  sensitive   = true
}
