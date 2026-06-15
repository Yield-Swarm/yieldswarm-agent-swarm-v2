# ---------------------------------------------------------------------------
# modules/vultr/main.tf
# Vultr VPS nodes for lightweight cron-based agent workloads.
# API key flows from the root Vault data source → Vultr provider.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Cloud-init user data: install Docker, pull image, run agent with Vault auth
  user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
    vault_addr              = var.vault_addr
    vault_approle_role_id   = var.vault_approle_role_id
    vault_approle_secret_id = var.vault_approle_secret_id
    agent_image             = var.agent_image
  }))
}

resource "vultr_firewall_group" "agentswarm" {
  description = "${local.name_prefix} agent firewall"
}

resource "vultr_firewall_rule" "ssh" {
  firewall_group_id = vultr_firewall_group.agentswarm.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "22"
  notes             = "SSH — restrict to your IP in production"
}

resource "vultr_firewall_rule" "agent_api" {
  firewall_group_id = vultr_firewall_group.agentswarm.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "8080"
  notes             = "Agent HTTP API"
}

resource "vultr_instance" "agent" {
  count = var.instance_count

  label              = "${local.name_prefix}-node-${count.index}"
  region             = var.region
  plan               = var.plan
  os_id              = var.os_id
  firewall_group_id  = vultr_firewall_group.agentswarm.id
  user_data          = local.user_data
  enable_ipv6        = true
  backups            = "disabled"

  tags = [var.project, var.environment, "agent"]
}
