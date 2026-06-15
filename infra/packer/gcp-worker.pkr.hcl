###############################################################################
# Packer: GCP image for AgentSwarm fallback workers.
#
# Output: a Compute Engine image named "<image_name>-<image_version>" in
# `gcp_project_id`. Feed its self-link/family to the Terraform variable
# `gcp_source_image`.
###############################################################################

packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1.1"
    }
  }
}

source "googlecompute" "worker" {
  project_id   = var.gcp_project_id
  zone         = var.gcp_zone
  machine_type = var.gcp_machine_type

  source_image_family = "ubuntu-2204-lts"
  ssh_username        = "packer"

  image_name        = "${var.image_name}-${var.image_version}"
  image_family      = var.image_name
  image_description = "AgentSwarm fallback worker (worker_image=${var.worker_image}, gpu=${var.enable_gpu})"
  disk_size         = 50
  disk_type         = "pd-balanced"

  image_labels = {
    project   = "yieldswarm"
    component = "worker-fallback"
    builder   = "packer"
  }
}

build {
  name    = "gcp-worker"
  sources = ["source.googlecompute.worker"]

  provisioner "shell" {
    environment_vars = [
      "WORKER_IMAGE=${var.worker_image}",
      "ENABLE_GPU=${var.enable_gpu}",
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/install-worker.sh"
  }
}
