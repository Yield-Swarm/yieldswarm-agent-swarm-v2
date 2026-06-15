# ---------------------------------------------------------------------------
# terraform/main.tf
# Root module — composes the cloud provider modules.
# All secrets are sourced from Vault via secrets.tf. Nothing is hardcoded.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Azure — Container Apps for scalable agent shards + blob storage
# ---------------------------------------------------------------------------
module "azure" {
  source = "./modules/azure"

  project          = var.project
  environment      = var.environment
  resource_group   = local.azure_resource_group
  location         = local.azure_location
  agent_image      = var.agent_image
  vault_addr       = var.vault_addr
  shard_count      = var.shard_count
  agents_per_shard = var.agents_per_shard
  min_replicas     = var.azure_min_replicas
  max_replicas     = var.azure_max_replicas
  cpu              = var.azure_container_cpu
  memory           = var.azure_container_memory

  # AppRole credentials for containers to authenticate with Vault at runtime.
  # role_id is non-sensitive; secret_id comes from Vault as a wrapped token.
  vault_approle_role_id   = var.vault_approle_role_id
  vault_approle_secret_id = var.vault_approle_secret_id

  # RPC endpoints injected as container env vars
  solana_rpc_url  = local.solana_rpc_url
  helius_api_key  = local.helius_api_key
}

# ---------------------------------------------------------------------------
# RunPod — GPU inference pods
# ---------------------------------------------------------------------------
module "runpod" {
  source = "./modules/runpod"

  project        = var.project
  environment    = var.environment
  agent_image    = var.agent_image
  gpu_type       = var.runpod_gpu_type
  gpu_count      = var.runpod_gpu_count
  container_disk = var.runpod_container_disk_size
  pod_count      = var.runpod_pod_count
  vault_addr     = var.vault_addr

  vault_approle_role_id   = var.vault_approle_role_id
  vault_approle_secret_id = var.vault_approle_secret_id

  network_volume_id = local.runpod_network_volume_id
}

# ---------------------------------------------------------------------------
# Vultr — lightweight VPS nodes
# ---------------------------------------------------------------------------
module "vultr" {
  source = "./modules/vultr"

  project        = var.project
  environment    = var.environment
  agent_image    = var.agent_image
  region         = var.vultr_region
  plan           = var.vultr_plan
  os_id          = var.vultr_os_id
  instance_count = var.vultr_instance_count
  vault_addr     = var.vault_addr

  vault_approle_role_id   = var.vault_approle_role_id
  vault_approle_secret_id = var.vault_approle_secret_id
}

# ---------------------------------------------------------------------------
# DigitalOcean — Droplets, Spaces bucket, managed Postgres
# ---------------------------------------------------------------------------
module "digitalocean" {
  source = "./modules/digitalocean"

  project        = var.project
  environment    = var.environment
  agent_image    = var.agent_image
  region         = var.do_region
  droplet_size   = var.do_droplet_size
  droplet_count  = var.do_droplet_count
  spaces_region  = var.do_spaces_region
  db_node_count  = var.do_db_node_count
  vault_addr     = var.vault_addr

  vault_approle_role_id   = var.vault_approle_role_id
  vault_approle_secret_id = var.vault_approle_secret_id
}
