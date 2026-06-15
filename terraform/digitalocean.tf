resource "digitalocean_droplet" "agent_monitor" {
  image    = "ubuntu-22-04-x64"
  name     = "yieldswarm-monitor-${var.environment}"
  region   = var.do_region
  size     = "s-2vcpu-4gb"
  tags     = ["yieldswarm", var.environment]
  ssh_keys = []

  user_data = templatefile("${path.module}/templates/do-init.sh.tpl", {
    vault_addr = var.vault_addr
  })
}

resource "digitalocean_spaces_bucket" "agent_artifacts" {
  name   = "yieldswarm-artifacts-${var.environment}"
  region = local.digitalocean.spaces_region
}

output "digitalocean_monitor_ip" {
  description = "DigitalOcean monitoring droplet IP"
  value       = digitalocean_droplet.agent_monitor.ipv4_address
}

output "digitalocean_spaces_bucket" {
  description = "Spaces bucket for agent artifacts"
  value       = digitalocean_spaces_bucket.agent_artifacts.bucket_domain_name
}
