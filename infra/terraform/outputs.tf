output "vault_secret_paths" {
  description = "Vault paths that the consumer Terraform stack expects to exist."
  value = {
    azure        = "${var.vault_kv_mount_path}/providers/azure"
    runpod       = "${var.vault_kv_mount_path}/providers/runpod"
    vultr        = "${var.vault_kv_mount_path}/providers/vultr"
    digitalocean = "${var.vault_kv_mount_path}/providers/digitalocean"
    rpc          = "${var.vault_kv_mount_path}/network/rpc"
  }
}
