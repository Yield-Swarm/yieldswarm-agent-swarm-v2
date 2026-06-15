resource "vultr_instance" "agent_bastion" {
  plan        = "vc2-2c-4gb"
  region      = var.vultr_region
  os_id       = 1743 # Ubuntu 22.04 LTS
  hostname    = "yieldswarm-bastion-${var.environment}"
  label       = "yieldswarm-bastion"
  tags        = [var.environment, "yieldswarm"]
  enable_ipv6 = true

  user_data = base64encode(templatefile("${path.module}/templates/vultr-init.sh.tpl", {
    vault_addr = var.vault_addr
  }))
}

output "vultr_bastion_ip" {
  description = "Vultr bastion public IP"
  value       = vultr_instance.agent_bastion.main_ip
}
