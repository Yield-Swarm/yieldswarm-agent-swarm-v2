###############################################################################
# Packer: Azure managed image for AgentSwarm fallback workers.
#
# Output: a managed image in `azure_resource_group` named
# "<image_name>-<image_version>". Feed its resource ID to the Terraform
# variable `azure_source_image_id`.
###############################################################################

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

source "azure-arm" "worker" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  managed_image_name                = "${var.image_name}-${var.image_version}"
  managed_image_resource_group_name = var.azure_resource_group

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"

  location = var.azure_location
  vm_size  = var.azure_vm_size

  azure_tags = {
    project   = "yieldswarm"
    component = "worker-fallback"
    builder   = "packer"
  }
}

build {
  name    = "azure-worker"
  sources = ["source.azure-arm.worker"]

  provisioner "shell" {
    environment_vars = [
      "WORKER_IMAGE=${var.worker_image}",
      "ENABLE_GPU=${var.enable_gpu}",
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/install-worker.sh"
  }

  # Azure requires deprovisioning before image capture.
  provisioner "shell" {
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync",
    ]
    inline_shebang    = "/bin/sh -x"
    execute_command   = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    expect_disconnect = true
  }
}
