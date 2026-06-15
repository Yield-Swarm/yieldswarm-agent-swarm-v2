# terraform/digitalocean.tf
# DigitalOcean infrastructure for YieldSwarm.
# The DO API token is read from Vault (local.do_creds.token) and
# exported as DIGITALOCEAN_TOKEN by vault-env.sh.

# ---------------------------------------------------------------------------
# Project — groups all DO resources
# ---------------------------------------------------------------------------
resource "digitalocean_project" "yieldswarm" {
  name        = "YieldSwarm AgentSwarm v2"
  description = "YieldSwarm AgentSwarm OS v2 — DePIN AI agent infrastructure"
  purpose     = "Service or API"
  environment = "Production"
}

# ---------------------------------------------------------------------------
# VPC — dedicated network for isolation
# ---------------------------------------------------------------------------
resource "digitalocean_vpc" "main" {
  name     = "vpc-yieldswarm-prod"
  region   = var.do_region
  ip_range = "10.20.0.0/16"
}

# ---------------------------------------------------------------------------
# SSH Key
# ---------------------------------------------------------------------------
resource "digitalocean_ssh_key" "deployer" {
  name       = "yieldswarm-deployer"
  public_key = file("~/.ssh/id_ed25519.pub")

  lifecycle {
    ignore_changes = [public_key]
  }
}

# ---------------------------------------------------------------------------
# Droplet — overflow agent / backup coordination node
# ---------------------------------------------------------------------------
resource "digitalocean_droplet" "coordinator" {
  name      = "yieldswarm-coordinator"
  region    = var.do_region
  size      = var.do_droplet_size
  image     = var.do_droplet_image
  vpc_uuid  = digitalocean_vpc.main.id
  ssh_keys  = [digitalocean_ssh_key.deployer.fingerprint]
  monitoring = true
  ipv6       = false
  backups    = true

  # Only VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID reach the Droplet.
  # entrypoint.sh fetches everything else from Vault.
  user_data = templatefile("${path.module}/templates/do-cloud-init.yaml.tpl", {
    vault_addr      = var.vault_addr
    vault_role_id   = "CONFIGURE_AFTER_VAULT_SETUP"
    vault_secret_id = "CONFIGURE_AFTER_VAULT_SETUP"
    agent_image     = var.azure_container_image
    log_level       = "INFO"
  })

  tags = [for k, v in var.tags : "${k}:${v}"]

  lifecycle {
    ignore_changes = [user_data, ssh_keys]
  }
}

# ---------------------------------------------------------------------------
# Firewall — restrict inbound traffic
# ---------------------------------------------------------------------------
resource "digitalocean_firewall" "coordinator" {
  name = "fw-yieldswarm-coordinator"

  droplet_ids = [digitalocean_droplet.coordinator.id]

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
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ---------------------------------------------------------------------------
# Spaces (S3-compatible object storage) — for agent state / checkpoints
# ---------------------------------------------------------------------------
resource "digitalocean_spaces_bucket" "agent_state" {
  name   = "yieldswarm-agent-state"
  region = var.do_region
  acl    = "private"

  versioning {
    enabled = true
  }
}

# ---------------------------------------------------------------------------
# Project assignment
# ---------------------------------------------------------------------------
resource "digitalocean_project_resources" "main" {
  project = digitalocean_project.yieldswarm.id
  resources = [
    digitalocean_droplet.coordinator.urn,
    digitalocean_spaces_bucket.agent_state.urn,
  ]
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "do_droplet_ip" {
  description = "Public IPv4 of the DigitalOcean coordinator Droplet."
  value       = digitalocean_droplet.coordinator.ipv4_address
}

output "do_spaces_bucket" {
  description = "DigitalOcean Spaces bucket for agent state."
  value       = digitalocean_spaces_bucket.agent_state.bucket_domain_name
}
