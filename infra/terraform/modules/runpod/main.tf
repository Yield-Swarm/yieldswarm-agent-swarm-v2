terraform {
  required_version = ">= 1.6.0"
  required_providers {
    restapi = {
      source                = "Mastercard/restapi"
      version               = "~> 1.20"
      configuration_aliases = [restapi]
    }
  }
}

variable "environment" { type = string }
variable "default_region" { type = string }

# Each pod is defined by a small, declarative spec. The module wraps the
# RunPod GraphQL `podFindAndDeployOnDemand` mutation in a restapi_object
# resource so Terraform tracks the pod ID in state and tears it down on
# `destroy`.
variable "pods" {
  description = "Map of logical pod name -> spec."
  type = map(object({
    gpu_type_id     = string
    gpu_count       = number
    container_image = string
    cloud_type      = optional(string, "SECURE")
    volume_in_gb    = optional(number, 40)
    container_disk  = optional(number, 20)
    min_vcpu_count  = optional(number, 4)
    min_memory_gb   = optional(number, 16)
    ports           = optional(string, "8888/http,22/tcp")
  }))
  default = {}
}

resource "restapi_object" "pod" {
  for_each = var.pods

  path         = "/"
  id_attribute = "data/podFindAndDeployOnDemand/id"
  read_path    = "/"
  destroy_path = "/"

  create_method  = "POST"
  update_method  = "POST"
  destroy_method = "POST"

  # GraphQL mutation body. Variables that originate from secrets (e.g.
  # registry credentials) must be referenced by Vault Agent template at
  # runtime; never inline them here.
  data = jsonencode({
    query = <<-GQL
      mutation Deploy($input: PodFindAndDeployOnDemandInput!) {
        podFindAndDeployOnDemand(input: $input) {
          id
          imageName
          machineId
        }
      }
    GQL
    variables = {
      input = {
        name              = "apn-${var.environment}-${each.key}"
        cloudType         = each.value.cloud_type
        gpuTypeId         = each.value.gpu_type_id
        gpuCount          = each.value.gpu_count
        containerDiskInGb = each.value.container_disk
        volumeInGb        = each.value.volume_in_gb
        minVcpuCount      = each.value.min_vcpu_count
        minMemoryInGb     = each.value.min_memory_gb
        imageName         = each.value.container_image
        ports             = each.value.ports
      }
    }
  })

  destroy_data = jsonencode({
    query = <<-GQL
      mutation Terminate($input: PodTerminateInput!) {
        podTerminate(input: $input)
      }
    GQL
    variables = {
      input = { podId = "{id}" }
    }
  })
}

output "pod_ids" {
  value = { for k, v in restapi_object.pod : k => v.id }
}
