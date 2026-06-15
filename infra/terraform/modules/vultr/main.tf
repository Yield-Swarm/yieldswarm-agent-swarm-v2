## Vultr module - VPC + compute fleet for AgentSwarm cron shards.
## Credentials configured at the root provider.

terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = ">= 2.21"
    }
  }
}

resource "vultr_vpc" "net" {
  region         = var.region
  description    = "yieldswarm-${var.environment}"
  v4_subnet      = "10.42.0.0"
  v4_subnet_mask = 22
}

resource "vultr_instance" "shard" {
  count           = var.shard_count
  region          = var.region
  plan            = var.plan
  os_id           = 1743 # Ubuntu 22.04 LTS x64
  label           = "yieldswarm-shard-${var.environment}-${count.index}"
  hostname        = "yieldswarm-shard-${var.environment}-${count.index}"
  enable_ipv6     = true
  backups         = "enabled"
  ddos_protection = true
  vpc_ids         = [vultr_vpc.net.id]
  tags            = [for k, v in var.tags : "${k}=${v}"]

  backups_schedule {
    type = "daily"
    hour = 3
  }
}
