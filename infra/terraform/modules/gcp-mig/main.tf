resource "google_compute_health_check" "this" {
  count = var.enabled ? 1 : 0

  project = var.project_id
  name    = "${var.name}-hc"

  tcp_health_check {
    port = 22
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

resource "google_compute_instance_template" "this" {
  count = var.enabled ? 1 : 0

  project      = var.project_id
  name_prefix  = "${var.name}-tpl-"
  machine_type = var.machine_type
  tags         = var.tags

  disk {
    source_image = var.source_image
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    access_config {}
  }

  metadata_startup_script = var.startup_script

  dynamic "service_account" {
    for_each = var.service_account_email == null ? [] : [var.service_account_email]
    content {
      email  = service_account.value
      scopes = ["cloud-platform"]
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "this" {
  count = var.enabled ? 1 : 0

  project            = var.project_id
  name               = var.name
  region             = var.region
  base_instance_name = var.name
  target_size        = var.target_size

  distribution_policy_zones = var.zones

  version {
    instance_template = google_compute_instance_template.this[0].self_link
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.this[0].id
    initial_delay_sec = 300
  }
}

resource "google_compute_region_autoscaler" "this" {
  count = var.enabled && var.enable_autoscaling ? 1 : 0

  project = var.project_id
  name   = "${var.name}-as"
  region = var.region
  target = google_compute_region_instance_group_manager.this[0].id

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = 120

    cpu_utilization {
      target = var.cpu_target
    }
  }
}
