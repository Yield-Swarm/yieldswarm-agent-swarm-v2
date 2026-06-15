locals {
  supported_clouds = ["azure", "gcp", "runpod", "vultr"]

  normalized_active_clouds = distinct([
    for cloud in var.active_clouds :
    lower(trimspace(cloud))
    if contains(local.supported_clouds, lower(trimspace(cloud)))
  ])

  primary_cloud = length(local.normalized_active_clouds) > 0 ? local.normalized_active_clouds[0] : null

  deploy_set = var.deploy_all_targets ? local.normalized_active_clouds : (
    local.primary_cloud == null ? [] : [local.primary_cloud]
  )
}

module "azure_vmss" {
  source = "./modules/azure-vmss"

  enabled               = contains(local.deploy_set, "azure")
  create_resource_group = var.azure_create_resource_group

  resource_group_name = var.azure_resource_group_name
  location            = var.azure_location

  vmss_name      = var.azure_vmss_name
  subnet_id      = var.azure_subnet_id
  sku            = var.azure_vm_size
  instance_count = var.azure_instance_count

  admin_username = var.azure_admin_username
  ssh_public_key = var.azure_ssh_public_key

  source_image_id = var.azure_image_id
  custom_data     = var.azure_custom_data == null ? null : base64encode(var.azure_custom_data)

  tags = var.common_tags
}

module "gcp_mig" {
  source = "./modules/gcp-mig"

  enabled = contains(local.deploy_set, "gcp")

  project_id = var.gcp_project_id
  region     = var.gcp_region
  zones      = var.gcp_zones

  name         = var.gcp_mig_name
  machine_type = var.gcp_machine_type
  target_size  = var.gcp_instance_count

  network        = var.gcp_network
  subnetwork     = var.gcp_subnetwork
  source_image   = var.gcp_image
  startup_script = var.gcp_startup_script

  service_account_email = var.gcp_service_account_email
  tags                  = var.gcp_tags

  enable_autoscaling = var.gcp_enable_autoscaling
  min_replicas       = var.gcp_min_replicas
  max_replicas       = var.gcp_max_replicas
  cpu_target         = var.gcp_cpu_target
}

module "runpod" {
  source = "./modules/runpod"

  enabled = contains(local.deploy_set, "runpod")

  name                 = var.runpod_pod_name
  image_name           = var.runpod_image_name
  gpu_type_ids         = var.runpod_gpu_type_ids
  data_center_ids      = var.runpod_data_center_ids
  gpu_count            = var.runpod_gpu_count
  cloud_type           = var.runpod_cloud_type
  support_public_ip    = var.runpod_support_public_ip
  volume_in_gb         = var.runpod_volume_in_gb
  container_disk_in_gb = var.runpod_container_disk_in_gb
  network_volume_in_gb = var.runpod_network_volume_in_gb
  volume_mount_path    = var.runpod_volume_mount_path

  ports = var.runpod_ports
  env   = var.runpod_env
}

module "vultr" {
  source = "./modules/vultr"

  enabled = contains(local.deploy_set, "vultr")

  instance_count = var.vultr_instance_count
  label          = var.vultr_label
  hostname       = var.vultr_hostname

  region = var.vultr_region
  plan   = var.vultr_plan

  os_id    = var.vultr_os_id
  image_id = var.vultr_image_id

  ssh_key_ids = var.vultr_ssh_key_ids
  user_data   = var.vultr_user_data

  enable_ipv6 = var.vultr_enable_ipv6
  backups     = var.vultr_backups
  tags        = var.vultr_tags
}
