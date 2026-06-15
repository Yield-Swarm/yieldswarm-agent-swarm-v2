# ============================================================
# DigitalOcean Infrastructure — YieldSwarm AgentSwarm OS
#
# Resources:
#   - VPC for network isolation
#   - Droplet(s) for lightweight agent shards
#   - Spaces bucket for state/artifacts
#   - Firewall rules
#
# All credentials come from data.vault_generic_secret.do
# ============================================================

# ── VPC ───────────────────────────────────────────────────────
resource "digitalocean_vpc" "main" {
  name     = "${var.project_name}-vpc-${var.environment}"
  region   = var.do_region
  ip_range = "10.10.0.0/16"
}

# ── SSH key (public part only — private key never touches TF) ─
# Register your operator public key in DigitalOcean and supply
# the fingerprint as a data source; or import an existing key.
data "digitalocean_ssh_key" "operator" {
  name = "${var.project_name}-operator"
}

# ── Agent Droplet(s) ──────────────────────────────────────────
resource "digitalocean_droplet" "agent" {
  count    = var.do_droplet_count
  name     = "${var.project_name}-agent-${var.environment}-${count.index + 1}"
  region   = var.do_region
  size     = var.do_droplet_size
  image    = "ubuntu-22-04-x64"
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [data.digitalocean_ssh_key.operator.id]

  # Cloud-init: install Vault, Docker, and start the agent
  user_data = templatefile("${path.module}/templates/do-cloud-init.yaml", {
    vault_addr     = var.vault_address
    vault_role_id  = var.vault_role_id
    vault_secret_id = var.vault_secret_id
    environment    = var.environment
  })

  tags = [
    var.project_name,
    var.environment,
    "agentswarm",
  ]
}

# ── Firewall ──────────────────────────────────────────────────
resource "digitalocean_firewall" "agent" {
  name        = "${var.project_name}-fw-${var.environment}"
  droplet_ids = digitalocean_droplet.agent[*].id

  # Inbound: SSH from known operator CIDRs only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.do_operator_cidrs
  }

  # Inbound: health-check port from VPC only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = [digitalocean_vpc.main.ip_range]
  }

  # Outbound: all (agents call external APIs)
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

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ── Spaces bucket (object storage) ───────────────────────────
resource "digitalocean_spaces_bucket" "artifacts" {
  name   = "${var.project_name}-artifacts-${var.environment}"
  region = var.do_region
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
}

# ── Additional variable defaults referenced above ─────────────
# Add to variables.tf if not already present

variable "do_droplet_count" {
  description = "Number of DigitalOcean Droplets to provision for agent shards"
  type        = number
  default     = 2
}

variable "do_operator_cidrs" {
  description = "CIDR list allowed to SSH into agent Droplets"
  type        = list(string)
  default     = []
}
