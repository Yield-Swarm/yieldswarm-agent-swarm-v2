# =============================================================================
# YieldSwarm multi-cloud fallback orchestration.
#
# Akash is the PRIMARY (sovereign) backend. This Terraform config provides
# automatic fallback to managed clouds (Fly.io -> Render -> Hetzner, in
# preference order) and only provisions a fallback when:
#   (a) that fallback is enabled (enable_*), AND
#   (b) the primary Akash worker is unhealthy (primary_health_url probe fails).
#
# It uses provider CLIs via local-exec rather than per-cloud Terraform
# providers, so `terraform init/validate/plan` works without registry access to
# every cloud provider. The fallback deploy scripts live in ./scripts.
# =============================================================================

locals {
  worker_image    = "ghcr.io/${var.ghcr_owner}/${var.image_prefix}-worker:${var.image_tag}"
  dashboard_image = "ghcr.io/${var.ghcr_owner}/${var.image_prefix}-dashboard:${var.image_tag}"
  has_primary     = trimspace(var.primary_health_url) != ""
}

# ---- Probe the primary (Akash) worker -------------------------------------
data "external" "primary_health" {
  program = ["bash", "${path.module}/scripts/health-probe.sh"]
  query = {
    url = var.primary_health_url
  }
}

locals {
  # When there is no primary URL configured, treat primary as DOWN so the
  # selected fallback is provisioned. Otherwise honor the probe result.
  primary_healthy = local.has_primary ? (data.external.primary_health.result.healthy == "true") : false
  need_fallback   = !local.primary_healthy

  # First enabled fallback in preference order becomes active.
  active_fallback = (
    local.need_fallback && var.enable_fly ? "fly" :
    local.need_fallback && var.enable_render ? "render" :
    local.need_fallback && var.enable_hetzner ? "hetzner" :
    "none"
  )
}

# ---- Fly.io fallback -------------------------------------------------------
resource "null_resource" "fly" {
  count = local.active_fallback == "fly" ? 1 : 0

  triggers = {
    image  = local.worker_image
    region = var.fly_region
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-fly.sh"
    environment = {
      FLY_API_TOKEN = var.fly_api_token
      WORKER_IMAGE  = local.worker_image
      FLY_REGION    = var.fly_region
    }
  }
}

# ---- Render fallback -------------------------------------------------------
resource "null_resource" "render" {
  count = local.active_fallback == "render" ? 1 : 0

  triggers = {
    image = local.worker_image
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-render.sh"
    environment = {
      RENDER_API_KEY = var.render_api_key
      WORKER_IMAGE   = local.worker_image
    }
  }
}

# ---- Hetzner Cloud fallback -----------------------------------------------
resource "null_resource" "hetzner" {
  count = local.active_fallback == "hetzner" ? 1 : 0

  triggers = {
    image = local.worker_image
    type  = var.hetzner_server_type
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy-hetzner.sh"
    environment = {
      HCLOUD_TOKEN        = var.hcloud_token
      WORKER_IMAGE        = local.worker_image
      HETZNER_LOCATION    = var.hetzner_location
      HETZNER_SERVER_TYPE = var.hetzner_server_type
    }
  }
}

# ---- Record which backend is serving --------------------------------------
resource "local_file" "active_backend" {
  filename = "${path.module}/active-backend.json"
  content = jsonencode({
    generated_at    = timestamp()
    primary_url     = var.primary_health_url
    primary_healthy = local.primary_healthy
    active_fallback = local.active_fallback
    worker_image    = local.worker_image
  })
}
