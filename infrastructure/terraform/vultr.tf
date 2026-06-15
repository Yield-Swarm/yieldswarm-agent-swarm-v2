# vultr.tf
# Configures the official Vultr provider with credentials from Vault.

provider "vultr" {
  api_key     = try(local.vultr["api_key"], null)
  rate_limit  = 100
  retry_limit = 3
}

# Sample landing-zone resources. The actual GPU/DePIN inventory lives in
# the agent control plane; this resource just confirms the provider
# authenticates against the Vault-supplied key.
resource "vultr_ssh_key" "yieldswarm_ops" {
  count   = var.enable_vultr ? 1 : 0
  name    = "yieldswarm-${var.environment}-ops"
  ssh_key = try(local.vultr["ops_ssh_pubkey"], "ssh-ed25519 AAAA_REPLACE_ME ops@yieldswarm.local")
}

resource "vultr_firewall_group" "yieldswarm" {
  count       = var.enable_vultr ? 1 : 0
  description = "YieldSwarm ${var.environment} - workload egress + ops SSH"
}

resource "vultr_firewall_rule" "ops_ssh" {
  count             = var.enable_vultr ? 1 : 0
  firewall_group_id = vultr_firewall_group.yieldswarm[0].id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = try(local.vultr["ops_ssh_cidr"], "203.0.113.0/24")
  subnet_size       = 24
  port              = "22"
  notes             = "Ops SSH from corp egress"
}
