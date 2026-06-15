# =============================================================================
# Root composition. Each provider lives in its own module; toggle via
# `enable_<provider>` variables. Modules receive credentials EXCLUSIVELY via
# providers configured in providers.tf, which themselves read from Vault.
# =============================================================================

locals {
  name_prefix = "yieldswarm-${var.environment}"

  common_tags = merge(var.default_tags, {
    environment = var.environment
  })
}

module "azure" {
  source = "./modules/azure-core"
  count  = var.enable_azure ? 1 : 0

  name_prefix    = local.name_prefix
  resource_group = local.azure.resource_group
  location       = local.azure.location
  tags           = local.common_tags
}

module "runpod" {
  source = "./modules/runpod-gpu"
  count  = var.enable_runpod ? 1 : 0

  name_prefix      = local.name_prefix
  api_key          = local.runpod.api_key
  org_id           = local.runpod.org_id
  default_pod_type = local.runpod.default_pod_type
  tags             = local.common_tags
}

module "vultr" {
  source = "./modules/vultr-edge"
  count  = var.enable_vultr ? 1 : 0

  name_prefix    = local.name_prefix
  default_region = local.vultr.default_region
  default_plan   = local.vultr.default_plan
  tags           = local.common_tags
}

module "digitalocean" {
  source = "./modules/digitalocean-droplets"
  count  = var.enable_digitalocean ? 1 : 0

  name_prefix    = local.name_prefix
  default_region = local.digitalocean.default_region
  tags           = local.common_tags
}

module "rpc" {
  source = "./modules/rpc-endpoints"
  count  = var.enable_rpc ? 1 : 0

  endpoints = local.rpc
}
