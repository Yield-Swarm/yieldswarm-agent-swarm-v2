# terraform/runpod.tf
# RunPod GPU pod management via the RunPod GraphQL API.
# RunPod has no official Terraform provider, so we use the `http` provider
# to call the GraphQL API directly. The API key comes from Vault.
#
# The RunPod pod runs the same yieldswarm/agent-swarm Docker image and
# pulls secrets from Vault at startup via entrypoint.sh.

locals {
  runpod_api_key = local.runpod["api_key"]

  runpod_pod_mutation = jsonencode({
    query = <<-GQL
      mutation PodRentInterruptable(
        $input: PodRentInterruptableInput!
      ) {
        podRentInterruptable(input: $input) {
          id
          name
          imageName
          machineId
          desiredStatus
          runtime {
            ports {
              ip
              isIpPublic
              privatePort
              publicPort
              type
            }
          }
        }
      }
    GQL
    variables = {
      input = {
        cloudType            = "SECURE"
        gpuCount             = 1
        volumeInGb           = var.runpod_volume_in_gb
        containerDiskInGb    = var.runpod_container_disk_gb
        minVcpuCount         = 4
        minMemoryInGb        = 15
        gpuTypeId            = var.runpod_gpu_type_id
        name                 = var.runpod_pod_name
        imageName            = var.azure_container_image
        dockerArgs           = ""
        ports                = "8080/http"
        volumeMountPath      = "/workspace"
        env = [
          { key = "VAULT_ADDR",      value = var.vault_addr },
          { key = "VAULT_ROLE_ID",   value = "CONFIGURE_AFTER_VAULT_SETUP" },
          { key = "VAULT_SECRET_ID", value = "CONFIGURE_AFTER_VAULT_SETUP" },
          { key = "LOG_LEVEL",       value = "INFO" },
          { key = "GPU_MODE",        value = "true" },
        ]
      }
    }
  })
}

# ---------------------------------------------------------------------------
# Create / verify RunPod GPU pod via GraphQL API
# ---------------------------------------------------------------------------
resource "terraform_data" "runpod_pod" {
  # Re-run when the API key or pod name changes
  triggers_replace = [
    local.runpod_api_key,
    var.runpod_pod_name,
    var.runpod_gpu_type_id,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-BASH
      set -euo pipefail
      echo "[runpod] Submitting pod creation request to RunPod API..."
      RESPONSE=$(curl -s -X POST "${var.runpod_api_url}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${local.runpod_api_key}" \
        -d '${local.runpod_pod_mutation}')

      POD_ID=$(echo "$RESPONSE" | jq -r '.data.podRentInterruptable.id // empty')

      if [[ -z "$POD_ID" ]]; then
        echo "[runpod] ERROR: Pod creation failed."
        echo "$RESPONSE" | jq .
        exit 1
      fi

      echo "[runpod] Pod created successfully. ID: $POD_ID"
      echo "[runpod] Update VAULT_ROLE_ID and VAULT_SECRET_ID in the pod environment via RunPod console."
    BASH
  }
}

# ---------------------------------------------------------------------------
# Output — instructions since RunPod pod ID is not natively tracked by TF state
# ---------------------------------------------------------------------------
output "runpod_pod_note" {
  description = "Instructions for RunPod GPU pod."
  value       = <<-NOTE
    RunPod GPU pod '${var.runpod_pod_name}' has been requested.
    1. Log into console.runpod.io to find the pod ID.
    2. Set VAULT_ROLE_ID and VAULT_SECRET_ID in the pod environment.
    3. The container's entrypoint.sh will fetch all remaining secrets from Vault.
  NOTE
}
