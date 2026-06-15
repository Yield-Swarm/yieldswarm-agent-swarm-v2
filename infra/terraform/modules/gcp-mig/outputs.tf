output "summary" {
  description = "GCP MIG fallback summary."
  value = {
    provider             = "gcp"
    instance_group_name  = google_compute_instance_group_manager.this.name
    instance_group_self  = google_compute_instance_group_manager.this.instance_group
    zone                 = var.zone
    machine_type         = var.machine_type
    worker_count         = var.worker_count
    gpu                  = local.has_gpu ? "${var.gpu_count}x ${var.gpu_type}" : "none"
    using_packer_image   = var.source_image != ""
    instance_template_id = google_compute_instance_template.this.id
  }
}
