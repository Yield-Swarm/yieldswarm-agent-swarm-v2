# terraform/vultr.tf
# Vultr VPS for YieldSwarm coordination services.
# The Vultr API key is read from Vault (local.vultr_creds.api_key) and
# exported as VULTR_API_KEY by vault-env.sh so the provider picks it up.
# Cloud-init user-data installs Docker, then pulls and starts the agent image.
# Vault AppRole credentials are injected at cloud-init time — the entrypoint.sh
# fetches all other secrets from Vault at container startup.

data "vultr_ssh_key" "deployer" {
  filter {
    name   = "name"
    values = ["yieldswarm-deployer"]
  }
}

resource "vultr_instance" "coordinator" {
  plan      = var.vultr_plan
  region    = var.vultr_region
  os_id     = var.vultr_os_id
  label     = "yieldswarm-coordinator"
  hostname  = "coordinator.yieldswarm.io"
  ssh_key_ids = [data.vultr_ssh_key.deployer.id]

  # All sensitive values come from Vault via local.* and are rendered
  # into the cloud-init script. The script itself is not stored anywhere
  # after apply — it exists only in Terraform state (encrypt your backend).
  user_data = templatefile("${path.module}/templates/vultr-cloud-init.yaml.tpl", {
    vault_addr      = var.vault_addr
    vault_role_id   = "CONFIGURE_AFTER_VAULT_SETUP"
    vault_secret_id = "CONFIGURE_AFTER_VAULT_SETUP"
    agent_image     = var.azure_container_image
    log_level       = "INFO"
  })

  tags = [for k, v in var.tags : "${k}:${v}"]

  lifecycle {
    ignore_changes = [
      # Ignore user_data changes after initial creation to avoid re-provisioning
      user_data,
    ]
  }
}

output "vultr_instance_ip" {
  description = "Public IP of the Vultr coordinator instance."
  value       = vultr_instance.coordinator.main_ip
}

output "vultr_instance_id" {
  description = "Vultr instance ID."
  value       = vultr_instance.coordinator.id
}
