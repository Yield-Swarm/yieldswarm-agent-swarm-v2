# Vultr compute — API key from Vault.

resource "vultr_instance" "worker" {
  count = var.vultr_create_instance ? 1 : 0

  plan        = "vc2-2c-4gb"
  region      = local.vultr_secrets.default_region
  os_id       = 1743 # Ubuntu 22.04
  hostname    = "${var.project_name}-${var.environment}-vultr"
  label       = "${var.project_name}-${var.environment}"
  enable_ipv6 = true
  tags        = [var.project_name, var.environment]
}

output "vultr_default_region" {
  description = "Default Vultr region from Vault."
  value       = nonsensitive(local.vultr_secrets.default_region)
}

output "vultr_instance_ip" {
  description = "Vultr instance IP when provisioned."
  value       = try(vultr_instance.worker[0].main_ip, null)
}
