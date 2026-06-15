output "instance_ids" {
  value = var.enabled ? [for instance in vultr_instance.this : instance.id] : []
}

output "main_ips" {
  value = var.enabled ? [for instance in vultr_instance.this : instance.main_ip] : []
}
