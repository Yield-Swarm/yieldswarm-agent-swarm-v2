# runpod.tf
# RunPod ships a GraphQL-over-HTTPS API; the Mastercard/restapi provider
# is used here so we can talk to it without hard-coding the API key in any
# script. The key itself is sourced from Vault.

provider "restapi" {
  alias                = "runpod"
  uri                  = "https://api.runpod.io"
  write_returns_object = true
  debug                = false

  headers = {
    "Authorization" = "Bearer ${try(local.runpod["api_key"], "")}"
    "Content-Type"  = "application/json"
  }
}

# Sample: ensure the operator-defined pod template exists. The actual
# pod-spawning lives in the agent control plane; here we just demonstrate
# that the API key is wired and the provider authenticates.
data "restapi_object" "runpod_health" {
  count        = var.enable_runpod ? 1 : 0
  provider     = restapi.runpod
  path         = "/graphql"
  search_key   = "data"
  search_value = "myself"
  id_attribute = "data/myself/id"

  # GraphQL "ping" - retrieves the authenticated principal. If the API
  # key from Vault is wrong, this fails at plan time and surfaces a clear
  # auth error instead of silently provisioning under the wrong account.
  results_key = "data"
}

output "runpod_org_id" {
  description = "RunPod organisation id derived from Vault credential (sanity check)."
  value       = try(local.runpod["org_id"], null)
  sensitive   = true
}
