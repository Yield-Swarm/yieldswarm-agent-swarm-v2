terraform {
  required_version = ">= 1.6.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
  }
}

variable "environment" { type = string }
variable "default_region" { type = string }

variable "droplets" {
  description = "Map of logical name -> DO droplet spec."
  type = map(object({
    size       = string
    image      = optional(string, "ubuntu-22-04-x64")
    region     = optional(string)
    ssh_keys   = optional(list(string), [])
    vpc_uuid   = optional(string)
    tags       = optional(list(string), [])
    monitoring = optional(bool, true)
    backups    = optional(bool, true)
  }))
  default = {}
}

resource "digitalocean_droplet" "this" {
  for_each = var.droplets

  name       = "apn-${var.environment}-${each.key}"
  image      = each.value.image
  region     = coalesce(each.value.region, var.default_region)
  size       = each.value.size
  ssh_keys   = each.value.ssh_keys
  vpc_uuid   = each.value.vpc_uuid
  monitoring = each.value.monitoring
  backups    = each.value.backups
  ipv6       = true

  tags = concat(
    ["apn", var.environment, "vault-managed"],
    each.value.tags,
  )
}

output "droplet_ids" {
  value = { for k, v in digitalocean_droplet.this : k => v.id }
}
