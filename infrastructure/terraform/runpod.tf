# =============================================================================
# RunPod resources. RunPod has no first-party Terraform provider, so we use
# the community REST/GraphQL provider configured in providers.tf (alias
# `runpod`). The API key is supplied via the Authorization header from Vault.
#
# We register a "pod template" (cluster spec) that the agent scheduler can
# spin up on demand. No persistent pods are created here.
# =============================================================================

resource "restapi_object" "yieldswarm_pod_template" {
  count    = var.enabled_clouds.runpod ? 1 : 0
  provider = restapi.runpod

  path = "/" # GraphQL endpoint

  data = jsonencode({
    query = <<-GQL
      mutation SavePodTemplate($input: SaveTemplateInput!) {
        saveTemplate(input: $input) {
          id
          name
        }
      }
    GQL
    variables = {
      input = {
        name              = "yieldswarm-${var.environment}-agent"
        imageName         = "ghcr.io/yieldswarm/openclaw-akash:latest"
        dockerArgs        = ""
        containerDiskInGb = 20
        volumeInGb        = 50
        volumeMountPath   = "/workspace"
        ports             = "8080/http"
        env = [
          { key = "VAULT_ADDR", value = var.vault_address },
          { key = "VAULT_ROLE", value = "yieldswarm-akash" },
          { key = "RUNTIME_PROVIDER", value = "runpod" },
        ]
        isServerless = false
      }
    }
  })

  # RunPod returns the template id at .data.saveTemplate.id
  id_attribute   = "data/saveTemplate/id"
  read_path      = "/"
  destroy_method = "POST"
}
