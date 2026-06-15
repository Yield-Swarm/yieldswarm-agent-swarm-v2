# ============================================================
# Vultr Infrastructure — YieldSwarm AgentSwarm OS
#
# Resources:
#   - VPC 2.0 for isolation
#   - VPS instance(s) for agent shards
#   - Firewall group
#   - Object storage (optional)
#
# All credentials come from data.vault_generic_secret.vultr
# ============================================================

# ── VPC ───────────────────────────────────────────────────────
resource "vultr_vpc2" "main" {
  description   = "${var.project_name}-vpc-${var.environment}"
  region        = var.vultr_region
  ip_block      = "10.20.0.0"
  prefix_length = 24
}

# ── SSH key ───────────────────────────────────────────────────
resource "vultr_ssh_key" "operator" {
  name    = "${var.project_name}-operator"
  ssh_key = var.vultr_operator_ssh_pubkey
}

# ── Firewall group ────────────────────────────────────────────
resource "vultr_firewall_group" "agent" {
  description = "${var.project_name}-fw-${var.environment}"
}

resource "vultr_firewall_rule" "ssh" {
  firewall_group_id = vultr_firewall_group.agent.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "22"
  notes             = "SSH from operator CIDRs — restrict in production"
}

resource "vultr_firewall_rule" "healthcheck" {
  firewall_group_id = vultr_firewall_group.agent.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "10.20.0.0"
  subnet_size       = 24
  port              = "8080"
  notes             = "Agent health-check from VPC"
}

# ── VPS instance(s) ───────────────────────────────────────────
resource "vultr_instance" "agent" {
  count             = var.vultr_instance_count
  label             = "${var.project_name}-agent-${var.environment}-${count.index + 1}"
  region            = var.vultr_region
  plan              = var.vultr_plan
  os_id             = 1743  # Ubuntu 22.04 LTS x64
  vpc2_ids          = [vultr_vpc2.main.id]
  firewall_group_id = vultr_firewall_group.agent.id
  ssh_key_ids       = [vultr_ssh_key.operator.id]
  backups           = "disabled"
  ddos_protection   = false

  user_data = templatefile("${path.module}/templates/vultr-cloud-init.yaml", {
    vault_addr      = var.vault_address
    vault_role_id   = var.vault_role_id
    vault_secret_id = var.vault_secret_id
    environment     = var.environment
  })

  tags = [var.project_name, var.environment, "agentswarm"]
}

# ── Block storage (optional) ──────────────────────────────────
resource "vultr_block_storage" "agent_data" {
  count       = var.vultr_instance_count
  region      = var.vultr_region
  size_gb     = var.vultr_block_storage_gb
  label       = "${var.project_name}-data-${var.environment}-${count.index + 1}"
  attached_to_instance = vultr_instance.agent[count.index].id
  live        = true
}

# ── Additional variables ──────────────────────────────────────
variable "vultr_instance_count" {
  description = "Number of Vultr VPS instances to provision"
  type        = number
  default     = 1
}

variable "vultr_operator_ssh_pubkey" {
  description = "Operator SSH public key to inject into Vultr instances"
  type        = string
  default     = ""
}

variable "vultr_block_storage_gb" {
  description = "Size of attached block storage per Vultr instance (GB)"
  type        = number
  default     = 40
}
