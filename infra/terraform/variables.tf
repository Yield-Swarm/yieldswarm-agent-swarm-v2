variable "active_clouds" {
  description = "Priority-ordered cloud list for primary and fallback deployment."
  type        = list(string)
  default     = ["azure", "gcp", "runpod", "vultr"]

  validation {
    condition = (
      length(var.active_clouds) > 0 &&
      alltrue([for cloud in var.active_clouds : contains(["azure", "gcp", "runpod", "vultr"], lower(trimspace(cloud)))])
    )
    error_message = "active_clouds must contain one or more entries from: azure, gcp, runpod, vultr."
  }
}

variable "deploy_all_targets" {
  description = "Deploy to every cloud in active_clouds when true; only deploy primary cloud when false."
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags applied where provider supports tagging."
  type        = map(string)
  default = {
    workload = "helixchain"
    env      = "prod"
    managed  = "terraform"
  }
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure Subscription ID."
  default     = null
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure Tenant ID."
  default     = null
}

variable "azure_client_id" {
  type        = string
  description = "Azure client ID."
  default     = null
}

variable "azure_client_secret" {
  type        = string
  description = "Azure client secret."
  sensitive   = true
  default     = null
}

variable "gcp_credentials_json" {
  type        = string
  description = "GCP service account JSON content."
  sensitive   = true
  default     = null
}

variable "runpod_api_key" {
  type        = string
  description = "RunPod API key."
  sensitive   = true
  default     = null
}

variable "vultr_api_key" {
  type        = string
  description = "Vultr API key."
  sensitive   = true
  default     = null
}

variable "azure_create_resource_group" {
  type        = bool
  description = "Create Azure resource group in module."
  default     = true
}

variable "azure_resource_group_name" {
  type        = string
  description = "Azure resource group name."
  default     = "helixchain-prod-rg"
}

variable "azure_location" {
  type        = string
  description = "Azure region."
  default     = "eastus"
}

variable "azure_vmss_name" {
  type        = string
  description = "Azure VM Scale Set name."
  default     = "helixchain-vmss"
}

variable "azure_subnet_id" {
  type        = string
  description = "Subnet ID for the VMSS network interface."
}

variable "azure_vm_size" {
  type        = string
  description = "Azure VM size SKU."
  default     = "Standard_D4s_v5"
}

variable "azure_instance_count" {
  type        = number
  description = "Number of VMSS instances."
  default     = 2
}

variable "azure_admin_username" {
  type        = string
  description = "Admin username for Azure VMSS nodes."
  default     = "helix"
}

variable "azure_ssh_public_key" {
  type        = string
  description = "SSH public key for Azure VMSS nodes."
}

variable "azure_image_id" {
  type        = string
  description = "Custom image ID produced by Packer for Azure VMSS nodes."
}

variable "azure_custom_data" {
  type        = string
  description = "cloud-init/custom-data for VMSS instances."
  default     = null
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project ID."
}

variable "gcp_region" {
  type        = string
  description = "GCP region for regional MIG."
  default     = "us-central1"
}

variable "gcp_zones" {
  type        = list(string)
  description = "Zones used by the regional MIG."
  default     = ["us-central1-a", "us-central1-b"]
}

variable "gcp_mig_name" {
  type        = string
  description = "GCP regional managed instance group name."
  default     = "helixchain-mig"
}

variable "gcp_machine_type" {
  type        = string
  description = "Machine type for GCP instances."
  default     = "e2-standard-4"
}

variable "gcp_instance_count" {
  type        = number
  description = "Desired MIG size."
  default     = 2
}

variable "gcp_network" {
  type        = string
  description = "VPC network name or self link."
  default     = "default"
}

variable "gcp_subnetwork" {
  type        = string
  description = "Subnetwork name or self link."
  default     = "default"
}

variable "gcp_image" {
  type        = string
  description = "Image self-link from Packer googlecompute build."
}

variable "gcp_startup_script" {
  type        = string
  description = "Startup script executed on boot."
  default     = null
}

variable "gcp_service_account_email" {
  type        = string
  description = "Optional service account for instances."
  default     = null
}

variable "gcp_tags" {
  type        = list(string)
  description = "Network tags for instances."
  default     = ["helixchain", "prod"]
}

variable "gcp_enable_autoscaling" {
  type        = bool
  description = "Enable GCP MIG autoscaler."
  default     = true
}

variable "gcp_min_replicas" {
  type        = number
  description = "MIG autoscaler minimum replicas."
  default     = 2
}

variable "gcp_max_replicas" {
  type        = number
  description = "MIG autoscaler maximum replicas."
  default     = 6
}

variable "gcp_cpu_target" {
  type        = number
  description = "MIG autoscaler CPU target in range (0,1]."
  default     = 0.6
}

variable "runpod_pod_name" {
  type        = string
  description = "RunPod pod name."
  default     = "helixchain-prod"
}

variable "runpod_image_name" {
  type        = string
  description = "Container image used by RunPod."
  default     = "runpod/pytorch:2.1.0-py3.10-cuda11.8.0-devel"
}

variable "runpod_gpu_type_ids" {
  type        = list(string)
  description = "Preferred GPU type IDs/names for RunPod scheduling."
  default     = ["NVIDIA RTX A5000", "NVIDIA A40"]
}

variable "runpod_data_center_ids" {
  type        = list(string)
  description = "Preferred RunPod data centers."
  default     = ["US-TX-3", "US-KS-2"]
}

variable "runpod_gpu_count" {
  type        = number
  description = "GPUs per pod."
  default     = 1
}

variable "runpod_cloud_type" {
  type        = string
  description = "RunPod cloud type (ALL, SECURE, or COMMUNITY)."
  default     = "ALL"
}

variable "runpod_support_public_ip" {
  type        = bool
  description = "Expose a public IP for the RunPod pod."
  default     = true
}

variable "runpod_volume_in_gb" {
  type        = number
  description = "Persistent volume in GB attached to pod."
  default     = 100
}

variable "runpod_container_disk_in_gb" {
  type        = number
  description = "Container disk size in GB."
  default     = 30
}

variable "runpod_network_volume_in_gb" {
  type        = number
  description = "Create/attach RunPod network volume when greater than 0."
  default     = 0
}

variable "runpod_volume_mount_path" {
  type        = string
  description = "Mount path for RunPod network volume."
  default     = "/workspace"
}

variable "runpod_ports" {
  type        = list(string)
  description = "Exposed ports for RunPod pod."
  default     = ["22/tcp", "8080/http"]
}

variable "runpod_env" {
  type        = map(string)
  description = "Environment variables injected into RunPod pod."
  default = {
    HELIXCHAIN_ENV = "prod"
  }
}

variable "vultr_instance_count" {
  type        = number
  description = "How many Vultr instances to create."
  default     = 1
}

variable "vultr_label" {
  type        = string
  description = "Base Vultr instance label."
  default     = "helixchain-prod"
}

variable "vultr_hostname" {
  type        = string
  description = "Base Vultr hostname."
  default     = "helixchain"
}

variable "vultr_region" {
  type        = string
  description = "Vultr region code."
  default     = "ewr"
}

variable "vultr_plan" {
  type        = string
  description = "Vultr plan slug."
  default     = "vc2-2c-4gb"
}

variable "vultr_os_id" {
  type        = string
  description = "Vultr OS ID for stock OS deployment when image_id is null."
  default     = "1743"
}

variable "vultr_image_id" {
  type        = string
  description = "Optional custom image/snapshot ID from Packer."
  default     = null
}

variable "vultr_ssh_key_ids" {
  type        = list(string)
  description = "Vultr SSH key IDs."
  default     = []
}

variable "vultr_user_data" {
  type        = string
  description = "cloud-init for Vultr instances."
  default     = null
}

variable "vultr_enable_ipv6" {
  type        = bool
  description = "Enable IPv6 on Vultr instances."
  default     = true
}

variable "vultr_backups" {
  type        = string
  description = "Backup mode: enabled or disabled."
  default     = "disabled"
}

variable "vultr_tags" {
  type        = list(string)
  description = "Tags for Vultr instances."
  default     = ["helixchain", "prod"]
}
