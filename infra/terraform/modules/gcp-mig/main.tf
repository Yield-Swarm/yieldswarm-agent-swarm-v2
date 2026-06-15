###############################################################################
# GCP fallback: a zonal Managed Instance Group of AgentSwarm workers.
###############################################################################

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

locals {
  base_name    = "${var.name_prefix}-gcp"
  has_gpu      = var.gpu_type != "" && var.gpu_count > 0
  source_image = var.source_image != "" ? var.source_image : "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"

  startup_script = templatefile("${path.root}/templates/worker-bootstrap.sh.tftpl", {
    worker_image    = var.worker_image
    worker_provider = var.worker_provider
    worker_env      = var.worker_env
  })

  # GCP only accepts lowercase alphanumeric/underscore/dash label values.
  labels = { for k, v in var.labels : lower(k) => lower(replace(v, "/[^a-zA-Z0-9_-]/", "-")) }
}

resource "google_compute_instance_template" "this" {
  name_prefix  = "${local.base_name}-tmpl-"
  project      = var.project_id != "" ? var.project_id : null
  machine_type = var.machine_type
  region       = var.region
  tags         = ["agentswarm-worker", "fallback"]
  labels       = local.labels

  disk {
    source_image = local.source_image
    auto_delete  = true
    boot         = true
    disk_size_gb = 50
    disk_type    = "pd-balanced"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork != "" ? var.subnetwork : null

    access_config {
      # Ephemeral public IP so workers can reach the control plane.
    }
  }

  dynamic "guest_accelerator" {
    for_each = local.has_gpu ? [1] : []
    content {
      type  = var.gpu_type
      count = var.gpu_count
    }
  }

  # GPU instances cannot live-migrate.
  scheduling {
    on_host_maintenance = local.has_gpu ? "TERMINATE" : "MIGRATE"
    automatic_restart   = true
  }

  metadata = {
    startup-script = local.startup_script
    ssh-keys       = var.ssh_public_key != "" ? "${var.ssh_username}:${var.ssh_public_key}" : null
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "this" {
  name               = "${local.base_name}-hc-${var.unique_suffix}"
  project            = var.project_id != "" ? var.project_id : null
  check_interval_sec = 30
  timeout_sec        = 10

  tcp_health_check {
    port = 22
  }
}

resource "google_compute_instance_group_manager" "this" {
  name               = "${local.base_name}-mig-${var.unique_suffix}"
  project            = var.project_id != "" ? var.project_id : null
  zone               = var.zone
  base_instance_name = "${local.base_name}-worker"
  target_size        = var.worker_count

  version {
    instance_template = google_compute_instance_template.this.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.this.id
    initial_delay_sec = 300
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 1
  }
}
