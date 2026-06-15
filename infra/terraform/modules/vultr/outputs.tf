output "summary" {
  description = "Vultr fallback summary."
  value = {
    provider           = "vultr"
    worker_count       = var.worker_count
    region             = var.region
    plan               = var.plan
    using_packer_image = local.use_snapshot
    instance_ids       = vultr_instance.worker[*].id
    main_ips           = vultr_instance.worker[*].main_ip
  }
}
