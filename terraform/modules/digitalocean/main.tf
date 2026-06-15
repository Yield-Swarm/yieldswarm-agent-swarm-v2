# ---------------------------------------------------------------------------
# modules/digitalocean/main.tf
# DigitalOcean Droplets, Spaces bucket, and managed PostgreSQL.
# All API credentials flow from the root Vault data source → DO provider.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Cloud-init user data for Droplets
  user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
    vault_addr              = var.vault_addr
    vault_approle_role_id   = var.vault_approle_role_id
    vault_approle_secret_id = var.vault_approle_secret_id
    agent_image             = var.agent_image
  }))
}

# ---------------------------------------------------------------------------
# DigitalOcean project grouping
# ---------------------------------------------------------------------------
resource "digitalocean_project" "agentswarm" {
  name        = local.name_prefix
  description = "YieldSwarm AgentSwarm OS ${var.environment}"
  purpose     = "Web Application"
  environment = title(var.environment)
}

# ---------------------------------------------------------------------------
# Droplets
# ---------------------------------------------------------------------------
resource "digitalocean_droplet" "agent" {
  count = var.droplet_count

  name     = "${local.name_prefix}-node-${count.index}"
  region   = var.region
  size     = var.droplet_size
  image    = "debian-12-x64"
  user_data = local.user_data
  ipv6     = true
  monitoring = true

  tags = [var.project, var.environment]
}

# ---------------------------------------------------------------------------
# Spaces (S3-compatible object storage) for agent state and logs
# ---------------------------------------------------------------------------
resource "digitalocean_spaces_bucket" "agentswarm" {
  name   = "${local.name_prefix}-state"
  region = var.spaces_region
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire-old-logs"
    enabled = true
    prefix  = "logs/"

    expiration {
      days = 90
    }
  }
}

# ---------------------------------------------------------------------------
# Managed PostgreSQL — agent state persistence
# ---------------------------------------------------------------------------
resource "digitalocean_database_cluster" "agentswarm" {
  name       = "${local.name_prefix}-db"
  engine     = "pg"
  version    = "16"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = var.db_node_count

  tags = [var.project, var.environment]
}

resource "digitalocean_database_db" "agents" {
  cluster_id = digitalocean_database_cluster.agentswarm.id
  name       = "agents"
}

resource "digitalocean_database_user" "agentswarm" {
  cluster_id = digitalocean_database_cluster.agentswarm.id
  name       = "agentswarm"
}

# ---------------------------------------------------------------------------
# Assign all resources to the DO project
# ---------------------------------------------------------------------------
resource "digitalocean_project_resources" "agentswarm" {
  project = digitalocean_project.agentswarm.id
  resources = concat(
    digitalocean_droplet.agent[*].urn,
    [
      digitalocean_spaces_bucket.agentswarm.urn,
      digitalocean_database_cluster.agentswarm.urn,
    ]
  )
}
