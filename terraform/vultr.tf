# =============================================================================
# Vultr Resources
# YieldSwarm AgentSwarm OS v2.0
#
# API key comes from data.vault_kv_secret_v2.vultr (vault-data.tf).
# =============================================================================

# Lookup a Vultr OS image for the agent nodes
data "vultr_os" "ubuntu" {
  filter {
    name   = "name"
    values = ["Ubuntu 22.04 LTS x64"]
  }
}

data "vultr_plan" "agent" {
  filter {
    name   = "id"
    values = ["vc2-2c-4gb"]    # 2 vCPU, 4 GB RAM — adjust as needed
  }
}

# ---------------------------------------------------------------------------
# Agent node
# ---------------------------------------------------------------------------
resource "vultr_instance" "agentswarm_node" {
  plan     = data.vultr_plan.agent.id
  region   = var.vultr_region
  os_id    = data.vultr_os.ubuntu.id
  hostname = "yieldswarm-agent-01"
  label    = "yieldswarm-agent"
  tags     = ["yieldswarm", "agent", var.vault_environment]

  # Cloud-init user data: installs Vault Agent and starts the entrypoint.
  # VAULT_SECRET_ID is rotated per deployment; store it in Vault at:
  #   secret/yieldswarm/<env>/infra/vultr vault_secret_id
  user_data = templatefile("${path.module}/templates/cloud-init-agent.yaml.tpl", {
    vault_addr        = var.vault_addr
    vault_role_id     = data.vault_kv_secret_v2.vultr.data["vault_role_id"]
    vault_secret_id   = data.vault_kv_secret_v2.vultr.data["vault_secret_id"]
    vault_environment = var.vault_environment
  })
}
