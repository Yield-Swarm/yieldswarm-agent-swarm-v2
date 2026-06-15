###############################################################################
# Vultr fallback: one cloud instance per worker unit.
###############################################################################

terraform {
  required_providers {
    vultr = {
      source = "vultr/vultr"
    }
  }
}

locals {
  use_snapshot = var.snapshot_id != ""

  user_data = base64encode(templatefile("${path.root}/templates/worker-bootstrap.sh.tftpl", {
    worker_image    = var.worker_image
    worker_provider = var.worker_provider
    worker_env      = var.worker_env
  }))

  # Vultr tags are a flat list of strings.
  tag_list = [for k, v in var.tags : "${k}:${v}"]
}

resource "vultr_ssh_key" "this" {
  count   = var.ssh_public_key != "" ? 1 : 0
  name    = "${var.name_prefix}-vultr"
  ssh_key = var.ssh_public_key
}

resource "vultr_instance" "worker" {
  count = var.worker_count

  label    = "${var.name_prefix}-vultr-${count.index}"
  hostname = "${var.name_prefix}-vultr-${count.index}"
  region   = var.region
  plan     = var.plan

  os_id       = local.use_snapshot ? null : var.os_id
  snapshot_id = local.use_snapshot ? var.snapshot_id : null

  ssh_key_ids     = var.ssh_public_key != "" ? [vultr_ssh_key.this[0].id] : []
  user_data       = local.user_data
  enable_ipv6     = true
  backups         = "disabled"
  tags            = local.tag_list
  ddos_protection = false
}
