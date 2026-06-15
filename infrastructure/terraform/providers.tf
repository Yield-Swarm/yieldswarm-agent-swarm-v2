# =============================================================================
# Provider configurations. EVERY credential below originates from Vault.
# Static strings exist only for non-secret, structural values (region, plan).
# =============================================================================

provider "azurerm" {
  features {}

  # Only configured when Azure is enabled; otherwise the provider is inert and
  # the azure.tf resources are gated behind count = 0.
  subscription_id = try(local.azure_secret.subscription_id, null)
  tenant_id       = try(local.azure_secret.tenant_id, null)
  client_id       = try(local.azure_secret.client_id, null)
  client_secret   = try(local.azure_secret.client_secret, null)
}

provider "vultr" {
  api_key     = try(local.vultr_secret.api_key, "")
  rate_limit  = 700
  retry_limit = 3
}

provider "digitalocean" {
  token             = try(local.do_secret.token, "")
  spaces_access_id  = try(local.do_secret.spaces_access_key, null)
  spaces_secret_key = try(local.do_secret.spaces_secret_key, null)
}

# --- RunPod (REST/GraphQL) ---------------------------------------------------
# The community restapi provider lets us talk to RunPod's GraphQL endpoint.
# The bearer token is read from Vault and injected as the Authorization header.
provider "restapi" {
  alias                = "runpod"
  uri                  = try(local.runpod_secret.api_url, "https://api.runpod.io/graphql")
  write_returns_object = true
  debug                = false

  headers = {
    "Authorization" = "Bearer ${try(local.runpod_secret.api_key, "")}"
    "Content-Type"  = "application/json"
  }

  # RunPod is rate-limited; bail loudly rather than silently corrupting state.
  create_returns_object = true
  rate_limit            = 5
}
