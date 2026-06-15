# =========================================================================
# DigitalOcean: a small droplet pool that hosts the OpenClaw admin
# dashboard and acts as the primary Vault Agent staging surface for the
# YieldSwarm dashboard plane. Token sourced from Vault.
# =========================================================================

resource "digitalocean_ssh_key" "yieldswarm" {
  name       = "yieldswarm-${var.environment}"
  public_key = data.vault_kv_secret_v2.digitalocean.data["ssh_public_key"]
}

resource "digitalocean_droplet" "dashboard" {
  count    = var.agent_shard_count
  image    = "ubuntu-22-04-x64"
  name     = "yieldswarm-dash-${count.index}"
  region   = var.do_region
  size     = "s-2vcpu-4gb"
  ssh_keys = [digitalocean_ssh_key.yieldswarm.id]

  user_data = templatefile("${path.module}/cloud-init/vault-bootstrap.tftpl", {
    vault_addr              = "https://vault.yieldswarm.io:8200"
    vault_role_id           = local.agent_role_id
    vault_wrapped_secret_id = vault_approle_auth_backend_role_secret_id.do_agent.wrapping_token
    shard_id                = count.index
  })

  tags = ["yieldswarm", "env-${var.environment}", "role-dashboard"]
}

resource "digitalocean_firewall" "dashboard" {
  name        = "yieldswarm-dash-${var.environment}"
  droplet_ids = digitalocean_droplet.dashboard[*].id

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["10.0.0.0/8"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
