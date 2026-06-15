# ---------------------------------------------------------------------------
# Root module: composes the per-provider modules and forwards the secret
# payloads pulled from Vault. No module receives raw API keys from
# variables or files -- everything flows through Vault.
# ---------------------------------------------------------------------------

module "azure" {
  source = "./modules/azure"

  environment     = var.environment
  subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
  tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
  location        = try(data.vault_kv_secret_v2.azure.data["location"], "eastus")
}

module "runpod" {
  source = "./modules/runpod"

  providers = {
    restapi = restapi.runpod
  }

  environment    = var.environment
  default_region = try(data.vault_kv_secret_v2.runpod.data["default_region"], "US-CA-2")
}

module "vultr" {
  source = "./modules/vultr"

  environment    = var.environment
  default_region = try(data.vault_kv_secret_v2.vultr.data["default_region"], "ewr")
}

module "digitalocean" {
  source = "./modules/digitalocean"

  environment    = var.environment
  default_region = try(data.vault_kv_secret_v2.digitalocean.data["default_region"], "nyc3")
}

module "rpc" {
  source = "./modules/rpc"

  environment = var.environment
  # Forward the full per-chain map. The module turns it into the
  # consumer-facing artifacts (e.g. Azure Key Vault entries that Akash
  # workloads later pull via Vault Agent).
  chain_secrets = {
    for chain, secret in data.vault_kv_secret_v2.rpc :
    chain => secret.data
  }
}
