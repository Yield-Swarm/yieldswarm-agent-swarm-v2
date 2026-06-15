# =============================================================================
# DigitalOcean resources. We provision droplets + a Spaces bucket for cron
# artifact storage. All credentials are sourced from Vault.
# =============================================================================

resource "digitalocean_droplet" "agent_node" {
  count = var.enabled_clouds.digitalocean ? 1 : 0

  image      = "ubuntu-22-04-x64"
  name       = "yieldswarm-do-${var.environment}-${count.index}"
  region     = try(local.do_secret.default_region, "nyc3")
  size       = try(local.do_secret.default_size, "s-2vcpu-4gb")
  ipv6       = true
  monitoring = true
  backups    = true
  tags       = [for k, v in local.common_tags : "${k}_${v}"]

  ssh_keys = compact([try(local.do_secret.ssh_key_fingerprint, "")])

  user_data = templatefile("${path.module}/templates/cloud-init-agent.sh.tftpl", {
    vault_addr = var.vault_address
    role_id    = var.vault_role_id
  })
}

resource "digitalocean_spaces_bucket" "cron_artifacts" {
  count = var.enabled_clouds.digitalocean ? 1 : 0

  name   = "yieldswarm-${var.environment}-cron-artifacts"
  region = try(local.do_secret.default_region, "nyc3")
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    id      = "expire-old-artifacts"
    expiration {
      days = 90
    }
    noncurrent_version_expiration {
      days = 30
    }
  }
}
