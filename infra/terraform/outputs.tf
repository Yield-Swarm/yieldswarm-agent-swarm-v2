output "vault_secret_paths_in_use" {
  description = "Paths Terraform reads from Vault."
  value = [
    "${var.vault_cloud_mount}/terraform/azure",
    "${var.vault_cloud_mount}/terraform/runpod",
    "${var.vault_cloud_mount}/terraform/vultr",
    "${var.vault_cloud_mount}/terraform/digitalocean",
    "${var.vault_cloud_mount}/terraform/rpc",
  ]
}

output "rpc_endpoints" {
  description = "RPC endpoints loaded from Vault for downstream modules."
  value = {
    primary = local.rpc_primary_url
    backup  = local.rpc_backup_url
  }
  sensitive = true
}
