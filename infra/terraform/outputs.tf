output "deployment_plan" {
  description = "Resolved cloud priority and active deploy set."
  value = {
    active_clouds = local.normalized_active_clouds
    deploy_set    = local.deploy_set
  }
}

output "azure" {
  description = "Azure VMSS module outputs."
  value = {
    enabled             = contains(local.deploy_set, "azure")
    resource_group_name = module.azure_vmss.resource_group_name
    vmss_id             = module.azure_vmss.vmss_id
    vmss_name           = module.azure_vmss.vmss_name
  }
}

output "gcp" {
  description = "GCP MIG module outputs."
  value = {
    enabled                    = contains(local.deploy_set, "gcp")
    regional_mig_self_link     = module.gcp_mig.regional_mig_self_link
    instance_template_self_link = module.gcp_mig.instance_template_self_link
  }
}

output "runpod" {
  description = "RunPod module outputs."
  value = {
    enabled            = contains(local.deploy_set, "runpod")
    pod_id             = module.runpod.pod_id
    pod_desired_status = module.runpod.pod_desired_status
    network_volume_id  = module.runpod.network_volume_id
  }
}

output "vultr" {
  description = "Vultr module outputs."
  value = {
    enabled      = contains(local.deploy_set, "vultr")
    instance_ids = module.vultr.instance_ids
    main_ips     = module.vultr.main_ips
  }
}
