provider "digitalocean" {
  token = local.do_creds["api_token"]
}

resource "digitalocean_droplet" "agent_node" {
  name   = "yieldswarm-agent-${var.environment}"
  region = var.do_region
  size   = "s-2vcpu-4gb"
  image  = "ubuntu-22-04-x64"

  user_data = templatefile("${path.module}/templates/do-cloud-init.tpl", {
    vault_addr      = var.vault_addr
    vault_role_id   = var.vault_role_id
    vault_secret_id = var.vault_secret_id
    solana_rpc_url  = local.solana_rpc_url
  })

  tags = ["yieldswarm", var.environment]
}

resource "digitalocean_firewall" "agent_node" {
  name = "yieldswarm-agent-fw"

  droplet_ids = [digitalocean_droplet.agent_node.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = ["0.0.0.0/0", "::/0"]
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
