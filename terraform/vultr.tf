# =========================================================================
# Vultr: cheap CPU instances for the marketing + shard-harvesting crons.
# API key sourced from Vault via the vultr provider in providers.tf.
# =========================================================================

resource "vultr_ssh_key" "yieldswarm" {
  name    = "yieldswarm-${var.environment}"
  ssh_key = data.vault_kv_secret_v2.vultr.data["ssh_public_key"]
}

resource "vultr_instance" "cron_runner" {
  count       = var.agent_shard_count
  plan        = "vc2-1c-1gb"
  region      = var.vultr_region
  os_id       = 2284 # Ubuntu 22.04 LTS x64
  label       = "yieldswarm-cron-${count.index}"
  hostname    = "yieldswarm-cron-${count.index}"
  ssh_key_ids = [vultr_ssh_key.yieldswarm.id]

  # cloud-init script that installs the Vault Agent and starts the
  # YieldSwarm cron runner. The wrapped SecretID is templated in once
  # via terraform and the workload itself rotates everything from there.
  user_data = base64encode(templatefile("${path.module}/cloud-init/vault-bootstrap.tftpl", {
    vault_addr              = "https://vault.yieldswarm.io:8200"
    vault_role_id           = local.agent_role_id
    vault_wrapped_secret_id = vault_approle_auth_backend_role_secret_id.vultr_agent.wrapping_token
    shard_id                = count.index
  }))

  tags = ["yieldswarm", "env:${var.environment}", "shard:${count.index}"]
}
