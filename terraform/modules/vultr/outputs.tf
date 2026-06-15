output "instance_ips" {
  description = "Public IP addresses of Vultr instances."
  value       = vultr_instance.agent[*].main_ip
}

output "instance_ids" {
  description = "Vultr instance IDs."
  value       = vultr_instance.agent[*].id
}
