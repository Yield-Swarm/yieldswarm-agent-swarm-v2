packer {
  required_plugins {
    vultr = {
      source  = "github.com/vultr/vultr"
      version = ">= 2.3.2"
    }
  }
}

variable "vultr_api_key" {
  type      = string
  default   = env("VULTR_API_KEY")
  sensitive = true
}

variable "os_id" {
  type    = string
  default = "1743"
}

variable "plan_id" {
  type    = string
  default = "vc2-1c-2gb"
}

variable "region_id" {
  type    = string
  default = "ewr"
}

variable "snapshot_prefix" {
  type    = string
  default = "helixchain-vultr"
}

source "vultr" "helixchain" {
  api_key              = var.vultr_api_key
  os_id                = var.os_id
  plan_id              = var.plan_id
  region_id            = var.region_id
  ssh_username         = "root"
  state_timeout        = "35m"
  snapshot_description = "${var.snapshot_prefix}-${formatdate("YYYYMMDDhhmm", timestamp())}"
}

build {
  name    = "vultr-snapshot"
  sources = ["source.vultr.helixchain"]

  provisioner "shell" {
    script = "${path.root}/scripts/bootstrap.sh"
  }
}
