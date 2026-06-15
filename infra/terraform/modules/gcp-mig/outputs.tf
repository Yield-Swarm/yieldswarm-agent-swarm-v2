output "regional_mig_self_link" {
  value = var.enabled ? google_compute_region_instance_group_manager.this[0].self_link : null
}

output "instance_template_self_link" {
  value = var.enabled ? google_compute_instance_template.this[0].self_link : null
}
