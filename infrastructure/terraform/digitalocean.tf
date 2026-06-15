# digitalocean.tf
# Official DigitalOcean provider, credentials sourced from Vault.

provider "digitalocean" {
  token             = try(local.digitalocean["api_token"], null)
  spaces_access_id  = try(local.digitalocean["spaces_access_id"], null)
  spaces_secret_key = try(local.digitalocean["spaces_secret_key"], null)
}

resource "digitalocean_project" "yieldswarm" {
  count       = var.enable_digitalocean ? 1 : 0
  name        = "yieldswarm-${var.environment}"
  description = "YieldSwarm AgentSwarm OS workloads (${var.environment})"
  purpose     = "Service or API"
  environment = title(var.environment)
}

# Sample artifact registry for AgentSwarm container images.
resource "digitalocean_container_registry" "yieldswarm" {
  count                  = var.enable_digitalocean ? 1 : 0
  name                   = "yieldswarm-${var.environment}"
  subscription_tier_slug = "basic"
  region                 = try(local.digitalocean["default_region"], "nyc3")
}
