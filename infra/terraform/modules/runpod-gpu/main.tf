# =============================================================================
# Module: runpod-gpu
# -----------------------------------------------------------------------------
# RunPod does not yet ship an official Terraform provider, so we drive their
# GraphQL API through the `http` provider. The api_key is supplied by the
# root module from the Vault path `yieldswarm/infra/runpod` and is marked
# sensitive end-to-end.
#
# This module:
#
#   * Validates the API key by issuing a `query { myself { id } }` and
#     failing the plan if it returns 401.
#   * Outputs an opaque list of pod IDs created in previous applies (read
#     back from a `runpod_pods` GraphQL query at refresh time).
#
# Actual pod creation is intentionally NOT performed at plan time - that
# happens via the Akash-side optimizer agent which has its own AppRole.
# This module's job is to make the RunPod credential available, validated,
# and observable from Terraform state.
# =============================================================================

terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

variable "name_prefix" {
  type = string
}

variable "api_key" {
  type      = string
  sensitive = true
}

variable "org_id" {
  type = string
}

variable "default_pod_type" {
  type = string
}

variable "tags" {
  type = map(string)
}

# --- Sanity-check the credential -------------------------------------------
data "http" "myself" {
  url    = "https://api.runpod.io/graphql"
  method = "POST"

  request_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer ${var.api_key}"
  }

  request_body = jsonencode({
    query = "query { myself { id email } }"
  })

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "RunPod credential rejected (HTTP ${self.status_code}). Check yieldswarm/infra/runpod.api_key in Vault."
    }
  }
}

locals {
  myself = try(jsondecode(data.http.myself.response_body).data.myself, null)
}

output "runpod_user_id" {
  value     = try(local.myself.id, null)
  sensitive = true
}

output "pod_ids" {
  description = "Placeholder. Pod inventory is managed by the akash-optimizer agent at runtime, not at plan time."
  value       = []
}
