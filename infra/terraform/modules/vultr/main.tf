terraform {
  required_version = ">= 1.6.0"
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
  }
}

variable "environment" { type = string }
variable "default_region" { type = string }

variable "instances" {
  description = "Map of logical name -> Vultr instance spec."
  type = map(object({
    plan        = string
    os_id       = optional(number, 1743) # Ubuntu 22.04 x64
    region      = optional(string)
    label       = optional(string)
    tags        = optional(list(string), [])
    enable_ipv6 = optional(bool, true)
  }))
  default = {}
}

resource "vultr_instance" "this" {
  for_each = var.instances

  plan        = each.value.plan
  region      = coalesce(each.value.region, var.default_region)
  os_id       = each.value.os_id
  label       = coalesce(each.value.label, "apn-${var.environment}-${each.key}")
  hostname    = "apn-${var.environment}-${each.key}"
  enable_ipv6 = each.value.enable_ipv6
  backups     = "enabled"

  tags = concat(
    ["apn", var.environment, "vault-managed"],
    each.value.tags,
  )
}

output "instance_ids" {
  value = { for k, v in vultr_instance.this : k => v.id }
}
