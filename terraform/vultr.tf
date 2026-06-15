provider "vultr" {
  api_key = local.vultr_creds["api_key"]
}

resource "vultr_instance" "agent_node" {
  plan     = "vc2-2c-4gb"
  region   = var.vultr_region
  os_id    = 1743 # Ubuntu 22.04 LTS
  hostname = "yieldswarm-agent-${var.environment}"
  label    = "yieldswarm-agent"

  user_data = templatefile("${path.module}/templates/vultr-cloud-init.tpl", {
    vault_addr      = var.vault_addr
    vault_role_id   = var.vault_role_id
    vault_secret_id = var.vault_secret_id
    solana_rpc_url  = local.solana_rpc_url
  })

  tags = ["yieldswarm", var.environment]
}
