# =========================================================================
# RunPod: GPU pods for the mining + inference workloads. Driven through
# the GraphQL endpoint using the http provider. The API key is read from
# Vault and only ever appears in the Authorization header sent over TLS.
#
# Pod definitions are kept declarative via a JSON list in locals.
# =========================================================================

locals {
  runpod_api_key = data.vault_kv_secret_v2.runpod.data["api_key"]

  runpod_pods = [
    {
      name              = "akash-optimizer-gpu-1"
      image             = "ghcr.io/yield-swarm/yieldswarm-agent:latest"
      gpu_count         = 1
      gpu_type          = "NVIDIA RTX 4090"
      container_disk_gb = 50
      env = {
        AGENT_PROFILE = "gpu-optimizer"
      }
    },
  ]
}

# Create each pod via a POST to RunPod's GraphQL endpoint.
data "http" "runpod_create_pod" {
  for_each = { for p in local.runpod_pods : p.name => p }

  url    = var.runpod_endpoint
  method = "POST"
  request_headers = {
    Authorization = "Bearer ${local.runpod_api_key}"
    Content-Type  = "application/json"
    Accept        = "application/json"
  }
  request_body = jsonencode({
    query = <<-EOT
      mutation {
        podFindAndDeployOnDemand(input: {
          name: "${each.value.name}"
          imageName: "${each.value.image}"
          gpuCount: ${each.value.gpu_count}
          gpuTypeId: "${each.value.gpu_type}"
          containerDiskInGb: ${each.value.container_disk_gb}
          env: [
            ${join(",", [
    for k, v in each.value.env :
    "{ key: \"${k}\", value: \"${v}\" }"
])},
            { key: "VAULT_ADDR",              value: "https://vault.yieldswarm.io:8200" },
            { key: "VAULT_ROLE_ID",           value: "${local.agent_role_id}" },
            { key: "VAULT_WRAPPED_SECRET_ID", value: "${vault_approle_auth_backend_role_secret_id.runpod_agent.wrapping_token}" }
          ]
        }) {
          id
          desiredStatus
        }
      }
    EOT
})

lifecycle {
  postcondition {
    condition     = self.status_code == 200
    error_message = "RunPod pod ${each.key} create failed: ${self.response_body}"
  }
}
}

output "runpod_pod_ids" {
  description = "IDs of RunPod pods provisioned this run."
  value = {
    for k, v in data.http.runpod_create_pod :
    k => try(jsondecode(v.response_body).data.podFindAndDeployOnDemand.id, null)
  }
  sensitive = false
}
