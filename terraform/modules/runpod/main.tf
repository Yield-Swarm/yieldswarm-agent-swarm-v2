# terraform/modules/runpod/main.tf
#
# RunPod has no official Terraform provider, so we:
#   1. Validate the API key (size + optional live ping to the GraphQL endpoint).
#   2. Expose the credential as a sensitive output keyed for downstream modules
#      (deployment manifests, runpodctl wrappers, Akash bridge agents).
#
# The credential is *never* baked into a local file or rendered template.
# Anything that needs it must consume the output via module composition.

locals {
  # Minimal "whoami"-equivalent query: lists at most 1 pod so the call is cheap.
  verify_query = jsonencode({
    query = "query { myself { id email } }"
  })
}

data "http" "verify" {
  count = var.verify_api_key ? 1 : 0

  url    = "https://api.runpod.io/graphql"
  method = "POST"

  request_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer ${var.credentials.api_key}"
  }

  request_body = local.verify_query

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && !can(regex("\"errors\"", self.response_body))
      error_message = "RunPod API key verification failed (status ${self.status_code}). Rotate via vault kv put yieldswarm/providers/runpod api_key=..."
    }
  }
}
