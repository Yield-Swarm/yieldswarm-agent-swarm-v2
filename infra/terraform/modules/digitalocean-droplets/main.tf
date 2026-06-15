# =============================================================================
# Module: digitalocean-droplets
# -----------------------------------------------------------------------------
# DigitalOcean foundational resources:
#
#   * Project (groups all AgentSwarm droplets / Spaces / load balancers)
#   * VPC (private mesh for inter-droplet traffic)
#   * Spaces bucket for off-Akash artifact storage
#
# Like the other modules, the DigitalOcean API token comes from Vault via the
# provider in providers.tf - never as a variable here.
# =============================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "default_region" {
  type = string
}

variable "tags" {
  type = map(string)
}

resource "digitalocean_project" "agentswarm" {
  name        = var.name_prefix
  description = "YieldSwarm AgentSwarm OS"
  purpose     = "Web Application"
  environment = title(lookup(var.tags, "environment", "Production"))
}

resource "digitalocean_vpc" "this" {
  name     = "${var.name_prefix}-vpc"
  region   = var.default_region
  ip_range = "10.42.0.0/16"
}

resource "digitalocean_spaces_bucket" "artifacts" {
  name   = "${var.name_prefix}-artifacts"
  region = var.default_region
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "expire-noncurrent"
    enabled = true
    noncurrent_version_expiration {
      days = 90
    }
  }
}

output "project_id" {
  value = digitalocean_project.agentswarm.id
}

output "vpc_id" {
  value = digitalocean_vpc.this.id
}

output "spaces_bucket" {
  value = digitalocean_spaces_bucket.artifacts.name
}

output "droplet_ips" {
  description = "Placeholder - droplets are scaled at runtime by the akash-optimizer agent."
  value       = []
}
