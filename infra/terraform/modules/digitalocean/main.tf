## DigitalOcean module - VPC + droplet pool + Spaces bucket for shard state.
## Credentials configured at the root provider.

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.45"
    }
  }
}

resource "digitalocean_vpc" "net" {
  name     = "yieldswarm-${var.environment}"
  region   = var.region
  ip_range = "10.43.0.0/22"
}

resource "digitalocean_droplet" "shard" {
  count      = var.shard_count
  image      = "ubuntu-22-04-x64"
  name       = "yieldswarm-shard-${var.environment}-${count.index}"
  region     = var.region
  size       = var.droplet_size
  vpc_uuid   = digitalocean_vpc.net.id
  monitoring = true
  backups    = true
  ipv6       = true
  tags       = concat([for k, v in var.tags : "${k}:${v}"], ["env:${var.environment}"])
}

resource "digitalocean_spaces_bucket" "state" {
  name   = "yieldswarm-state-${var.environment}"
  region = var.region
  acl    = "private"

  versioning {
    enabled = true
  }
  lifecycle_rule {
    enabled = true
    noncurrent_version_expiration { days = 90 }
  }
}
