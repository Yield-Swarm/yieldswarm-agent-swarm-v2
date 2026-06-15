# DigitalOcean — API token and Spaces keys from Vault.

resource "digitalocean_droplet" "worker" {
  count = var.do_create_droplet ? 1 : 0

  name     = "${var.project_name}-${var.environment}-do"
  region   = local.do_secrets.default_region
  size     = "s-2vcpu-4gb"
  image    = "ubuntu-22-04-x64"
  tags     = [var.project_name, var.environment, "vault-secrets"]
}

output "digitalocean_default_region" {
  description = "Default DO region from Vault."
  value       = nonsensitive(local.do_secrets.default_region)
}

output "digitalocean_droplet_ip" {
  description = "DO droplet IP when provisioned."
  value       = try(digitalocean_droplet.worker[0].ipv4_address, null)
}
