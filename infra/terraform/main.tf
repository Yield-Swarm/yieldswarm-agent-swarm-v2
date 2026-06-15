###############################################################################
# Root module: multi-cloud worker fallback for AgentSwarm.
#
# When Akash is saturated, this module spins up an equivalent number of worker
# units across Azure (VMSS), GCP (Managed Instance Group), RunPod (GPU pods)
# and Vultr (instances). The worker deficit is computed as:
#
#   deficit = max(0, desired_total_workers - akash_current_workers)
#
# and distributed across the enabled providers proportionally to
# `fallback_weights` (rounded up so total capacity always >= deficit).
###############################################################################

locals {
  # How many workers the fallback fleet must supply.
  fallback_deficit = max(0, var.desired_total_workers - var.akash_current_workers)

  # Weight only the providers that are enabled; default missing weights to 1.
  effective_weights = {
    for p in var.enabled_fallbacks :
    p => lookup(var.fallback_weights, p, 1)
  }

  total_weight = length(local.effective_weights) > 0 ? sum(values(local.effective_weights)) : 0

  # Proportional, rounded-up allocation guarantees sum(allocations) >= deficit.
  raw_allocation = {
    for p, w in local.effective_weights :
    p => local.total_weight > 0 ? ceil(local.fallback_deficit * w / local.total_weight) : 0
  }

  # Apply the optional per-provider hard cap.
  worker_counts = {
    for p, n in local.raw_allocation :
    p => var.max_workers_per_provider > 0 ? min(n, var.max_workers_per_provider) : n
  }

  azure_workers  = lookup(local.worker_counts, "azure", 0)
  gcp_workers    = lookup(local.worker_counts, "gcp", 0)
  runpod_workers = lookup(local.worker_counts, "runpod", 0)
  vultr_workers  = lookup(local.worker_counts, "vultr", 0)

  # Non-secret environment shared by every worker, regardless of provider.
  base_worker_env = merge(
    {
      AGENTSWARM_ENV         = var.environment
      AGENTS_PER_SHARD       = tostring(var.agents_per_worker)
      CONTROL_PLANE_ENDPOINT = var.control_plane_endpoint
      WORKER_FALLBACK_MODE   = "true"
    },
    var.worker_env,
  )

  name_prefix = "${var.name_prefix}-${var.environment}"

  # Use the operator-supplied SSH key, or fall back to an auto-generated
  # break-glass key whose private half is exposed as a sensitive output.
  effective_ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : (
    length(tls_private_key.breakglass) > 0 ? tls_private_key.breakglass[0].public_key_openssh : ""
  )
}

# Stable suffix so globally-unique names (storage, DNS, etc.) don't collide.
resource "random_id" "suffix" {
  byte_length = 3
}

# Auto-generated break-glass SSH key, only when the operator did not supply one.
resource "tls_private_key" "breakglass" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "azure_vmss" {
  source = "./modules/azure-vmss"
  count  = contains(var.enabled_fallbacks, "azure") && local.azure_workers > 0 ? 1 : 0

  name_prefix         = local.name_prefix
  unique_suffix       = random_id.suffix.hex
  worker_count        = local.azure_workers
  location            = var.azure_location
  vm_size             = var.azure_vm_size
  source_image_id     = var.azure_source_image_id
  resource_group_name = var.azure_resource_group_name
  ssh_public_key      = local.effective_ssh_public_key
  worker_image        = var.worker_container_image
  worker_provider     = "azure"
  worker_env          = local.base_worker_env
  tags                = var.tags
}

module "gcp_mig" {
  source = "./modules/gcp-mig"
  count  = contains(var.enabled_fallbacks, "gcp") && local.gcp_workers > 0 ? 1 : 0

  name_prefix     = local.name_prefix
  unique_suffix   = random_id.suffix.hex
  worker_count    = local.gcp_workers
  project_id      = var.gcp_project_id
  region          = var.gcp_region
  zone            = var.gcp_zone
  machine_type    = var.gcp_machine_type
  gpu_type        = var.gcp_gpu_type
  gpu_count       = var.gcp_gpu_count
  source_image    = var.gcp_source_image
  network         = var.gcp_network
  subnetwork      = var.gcp_subnetwork
  ssh_public_key  = local.effective_ssh_public_key
  worker_image    = var.worker_container_image
  worker_provider = "gcp"
  worker_env      = local.base_worker_env
  labels          = var.tags
}

module "runpod" {
  source = "./modules/runpod"
  count  = contains(var.enabled_fallbacks, "runpod") && local.runpod_workers > 0 ? 1 : 0

  name_prefix          = local.name_prefix
  worker_count         = local.runpod_workers
  worker_image         = var.worker_container_image
  gpu_type_ids         = var.runpod_gpu_type_ids
  gpu_count            = var.runpod_gpu_count
  data_center_ids      = var.runpod_data_center_ids
  cloud_type           = var.runpod_cloud_type
  container_disk_in_gb = var.runpod_container_disk_in_gb
  volume_in_gb         = var.runpod_volume_in_gb
  worker_env           = local.base_worker_env
}

module "vultr" {
  source = "./modules/vultr"
  count  = contains(var.enabled_fallbacks, "vultr") && local.vultr_workers > 0 ? 1 : 0

  name_prefix     = local.name_prefix
  worker_count    = local.vultr_workers
  region          = var.vultr_region
  plan            = var.vultr_plan
  os_id           = var.vultr_os_id
  snapshot_id     = var.vultr_snapshot_id
  ssh_public_key  = local.effective_ssh_public_key
  worker_image    = var.worker_container_image
  worker_provider = "vultr"
  worker_env      = local.base_worker_env
  tags            = var.tags
}
