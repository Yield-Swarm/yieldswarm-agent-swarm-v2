packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.0.0"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "image_name" {
  type    = string
  default = "helixchain-gcp"
}

variable "image_family" {
  type    = string
  default = "helixchain"
}

variable "ssh_username" {
  type    = string
  default = "packer"
}

source "googlecompute" "helixchain" {
  project_id              = var.project_id
  source_image_family     = "ubuntu-2204-lts"
  source_image_project_id = ["ubuntu-os-cloud"]

  zone         = var.zone
  machine_type = var.machine_type
  ssh_username = var.ssh_username

  image_name   = "${var.image_name}-${formatdate("YYYYMMDDhhmm", timestamp())}"
  image_family = var.image_family

  labels = {
    workload = "helixchain"
    env      = "prod"
    built_by = "packer"
  }
}

build {
  name    = "gcp-mig-image"
  sources = ["source.googlecompute.helixchain"]

  provisioner "shell" {
    script = "${path.root}/scripts/bootstrap.sh"
  }
}
