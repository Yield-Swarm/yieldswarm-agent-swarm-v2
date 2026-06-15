# terraform/main.tf
#
# Root composition: read all secrets from Vault exactly once, fan out to the
# per-provider modules. Use the enable_* flags to short-circuit any provider
# you aren't using in a given environment (useful for break-glass / minimal
# plans during incident response).

module "vault_secrets" {
  source = "./modules/vault-secrets"

  kv_mount   = var.kv_mount
  rpc_chains = var.rpc_chains
}

module "azure" {
  source = "./modules/azure"
  count  = var.enable_azure ? 1 : 0

  credentials         = module.vault_secrets.azure
  location            = var.azure_location
  resource_group_name = var.azure_resource_group_name
}

module "runpod" {
  source = "./modules/runpod"
  count  = var.enable_runpod ? 1 : 0

  credentials    = module.vault_secrets.runpod
  verify_api_key = var.verify_runpod_api_key
}

module "vultr" {
  source = "./modules/vultr"
  count  = var.enable_vultr ? 1 : 0

  credentials = module.vault_secrets.vultr
}

module "digitalocean" {
  source = "./modules/digitalocean"
  count  = var.enable_digitalocean ? 1 : 0

  credentials    = module.vault_secrets.digitalocean
  default_region = var.digitalocean_default_region
}

module "rpc" {
  source = "./modules/rpc"

  endpoints       = module.vault_secrets.rpc
  required_chains = var.required_rpc_chains
}
