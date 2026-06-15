packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.0"
    }
  }
}

variable "base_image" {
  type    = string
  default = "ubuntu:22.04"
}

variable "repository" {
  type    = string
  default = "registry.example.com/helixchain/agent"
}

variable "tag" {
  type    = string
  default = "prod"
}

source "docker" "helixchain" {
  image  = var.base_image
  commit = true

  run_command = ["-d", "-i", "-t", "--entrypoint=/bin/bash", "{{.Image}}"]
}

build {
  name    = "runpod-container-image"
  sources = ["source.docker.helixchain"]

  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y --no-install-recommends ca-certificates curl git jq",
      "mkdir -p /opt/helixchain",
      "echo runpod > /opt/helixchain/runtime"
    ]
  }

  post-processor "docker-tag" {
    repository = var.repository
    tags       = [var.tag]
  }

  post-processor "manifest" {
    output = "runpod-image-manifest.json"
  }
}
