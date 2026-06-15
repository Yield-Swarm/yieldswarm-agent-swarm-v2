###############################################################################
# Packer: Vultr snapshot for AgentSwarm fallback workers.
#
# Output: a Vultr snapshot described "<image_name>-<image_version>". Feed its
# snapshot ID to the Terraform variable `vultr_snapshot_id`.
###############################################################################

packer {
  required_plugins {
    vultr = {
      source  = "github.com/vultr/vultr"
      version = "~> 2.0"
    }
  }
}

source "vultr" "worker" {
  api_key              = var.vultr_api_key
  os_id                = var.vultr_os_id
  plan_id              = var.vultr_plan
  region_id            = var.vultr_region
  snapshot_description = "${var.image_name}-${var.image_version}"
  ssh_username         = "root"
  state_timeout        = "25m"
}

build {
  name    = "vultr-worker"
  sources = ["source.vultr.worker"]

  provisioner "shell" {
    environment_vars = [
      "WORKER_IMAGE=${var.worker_image}",
      "ENABLE_GPU=${var.enable_gpu}",
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/install-worker.sh"
  }
}
