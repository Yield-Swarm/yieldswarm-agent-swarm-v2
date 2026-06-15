## main.tf
## Composition layer.  Each cloud module receives ONLY the secrets and
## non-secret config it strictly needs, sourced via the `vault.tf` locals.

module "azure" {
  count  = var.enable_azure ? 1 : 0
  source = "./modules/azure"

  environment    = var.environment
  location       = try(local.azure_creds["location"], "westus2")
  resource_group = try(local.azure_creds["resource_group"], "yieldswarm-${var.environment}")
  tags           = var.tags

  # Credentials are already wired into the azurerm provider; this module
  # only needs non-sensitive shape config.
}

module "runpod" {
  count  = var.enable_runpod ? 1 : 0
  source = "./modules/runpod"

  environment     = var.environment
  pod_template_id = try(local.runpod_creds["pod_template_id"], null)
  tags            = var.tags
}

module "vultr" {
  count  = var.enable_vultr ? 1 : 0
  source = "./modules/vultr"

  environment = var.environment
  region      = try(local.vultr_creds["region"], "ewr")
  plan        = try(local.vultr_creds["plan"], "vc2-2c-4gb")
  tags        = var.tags
}

module "digitalocean" {
  count  = var.enable_digitalocean ? 1 : 0
  source = "./modules/digitalocean"

  environment  = var.environment
  region       = try(local.digitalocean_creds["region"], "nyc3")
  droplet_size = try(local.digitalocean_creds["droplet_size"], "s-2vcpu-4gb")
  tags         = var.tags
}

module "rpc" {
  source = "./modules/rpc"

  environment    = var.environment
  vault_kv_mount = var.vault_kv_mount
  rpc_secrets    = local.rpc_secrets

  # The RPC module materialises non-secret URLs / metadata as outputs and
  # writes runtime-only secrets into a downstream Vault path
  # (`kv/data/yieldswarm/<env>/runtime/rpc-resolved`) that the Akash
  # workload consumes.
}
