# HCP Packer — push worker images to HCP Packer registry (yield-swarm-org).
#
# Prerequisites:
#   hcp auth login
#   export HCP_PACKER_REGISTRY=<registry-name>
#
# Usage:
#   packer init .
#   packer build -var-file=worker.pkrvars.hcl -var-file=hcp-registry.pkrvars.hcl .

packer {
  required_plugins {
    hcp = {
      source  = "github.com/hashicorp/hcp"
      version = "~> 1.0"
    }
  }
}

variable "hcp_packer_registry" {
  type        = string
  description = "HCP Packer registry name in YieldSwarmHasiCorp"
  default     = "yieldswarm-worker"
}

variable "hcp_packer_bucket" {
  type        = string
  description = "Bucket name within the registry"
  default     = "agentswarm-worker"
}

variable "image_version" {
  type    = string
  default = "1.0.0"
}

source "hcp-packer" "worker" {
  bucket_name  = var.hcp_packer_bucket
  registry     = var.hcp_packer_registry
  image_name   = "agentswarm-worker-${var.image_version}"
  location     = "global"
}

build {
  name    = "hcp-registry-worker"
  sources = ["source.hcp-packer.worker"]

  # Reuse the same install script as cloud-specific builds
  provisioner "shell" {
    script = "${path.root}/scripts/install-worker.sh"
    environment_vars = [
      "WORKER_IMAGE=ghcr.io/yieldswarm/agentswarm-worker:latest",
      "ENABLE_GPU=false",
    ]
  }
}
