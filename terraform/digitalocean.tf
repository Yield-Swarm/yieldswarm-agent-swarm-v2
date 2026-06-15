# =============================================================================
# DigitalOcean Resources
# YieldSwarm AgentSwarm OS v2.0
#
# API token comes from data.vault_kv_secret_v2.digitalocean (vault-data.tf).
# =============================================================================

# Lookup the latest Ubuntu 22.04 LTS droplet image
data "digitalocean_image" "ubuntu" {
  slug = "ubuntu-22-04-x64"
}

# ---------------------------------------------------------------------------
# Droplet: agent worker node
# ---------------------------------------------------------------------------
resource "digitalocean_droplet" "agentswarm_node" {
  name   = "yieldswarm-agent-01"
  size   = "s-2vcpu-4gb"        # adjust to s-4vcpu-8gb for heavier shards
  region = var.do_region
  image  = data.digitalocean_image.ubuntu.slug

  tags = ["yieldswarm", "agent", var.vault_environment]

  # Cloud-init: bootstraps Vault Agent on first boot
  user_data = templatefile("${path.module}/templates/cloud-init-agent.yaml.tpl", {
    vault_addr        = var.vault_addr
    vault_role_id     = data.vault_kv_secret_v2.digitalocean.data["vault_role_id"]
    vault_secret_id   = data.vault_kv_secret_v2.digitalocean.data["vault_secret_id"]
    vault_environment = var.vault_environment
  })
}

# ---------------------------------------------------------------------------
# Firewall: only allow required ports
# ---------------------------------------------------------------------------
resource "digitalocean_firewall" "agentswarm" {
  name    = "yieldswarm-agents-fw"
  droplet_ids = [digitalocean_droplet.agentswarm_node.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]    # Restrict to ops IPs in production
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
