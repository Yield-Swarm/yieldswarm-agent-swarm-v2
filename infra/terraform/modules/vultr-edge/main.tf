# =============================================================================
# Module: vultr-edge
# -----------------------------------------------------------------------------
# Provisions a hardened Vultr SSH key + reserved IP and exposes the region
# defaults so other modules can spin up instances on demand. The Vultr API
# key itself is supplied by the vultr provider in providers.tf, which reads
# it from Vault.
# =============================================================================

terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "default_region" {
  type = string
}

variable "default_plan" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "ssh_public_key" {
  description = "PEM-formatted public SSH key authorised on all Vultr instances. Sourced from Vault by the root module when used in production."
  type        = string
  default     = null
}

resource "vultr_ssh_key" "agentswarm" {
  count   = var.ssh_public_key == null ? 0 : 1
  name    = "${var.name_prefix}-agentswarm"
  ssh_key = trimspace(var.ssh_public_key)
}

resource "vultr_reserved_ip" "edge" {
  region  = var.default_region
  ip_type = "v4"
  label   = "${var.name_prefix}-edge"
}

output "ssh_key_id" {
  value = try(vultr_ssh_key.agentswarm[0].id, null)
}

output "reserved_ip" {
  value = vultr_reserved_ip.edge.subnet
}

output "instance_ips" {
  description = "Placeholder. Active instances are managed by the akash-optimizer agent."
  value       = []
}
