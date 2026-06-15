resource "vultr_instance" "this" {
  count = var.enabled ? var.instance_count : 0

  plan   = var.plan
  region = var.region

  label    = format("%s-%02d", var.label, count.index + 1)
  hostname = format("%s-%02d", var.hostname, count.index + 1)

  os_id    = var.image_id == null ? var.os_id : null
  image_id = var.image_id

  ssh_key_ids = var.ssh_key_ids
  user_data   = var.user_data

  enable_ipv6 = var.enable_ipv6
  backups     = var.backups
  tags        = var.tags
}
