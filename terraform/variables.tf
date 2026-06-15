variable "vault_addr" {
  description = "Vault server address. Defaults to VAULT_ADDR env var if empty."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Azure
# ---------------------------------------------------------------------------
variable "azure_location" {
  description = "Primary Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "azure_resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
  default     = "rg-yieldswarm-prod"
}

variable "azure_container_app_name" {
  description = "Name of the Azure Container App running the agent swarm."
  type        = string
  default     = "ca-yieldswarm-agents"
}

variable "azure_container_cpu" {
  description = "CPU cores allocated to each Container App replica."
  type        = number
  default     = 0.5
}

variable "azure_container_memory" {
  description = "Memory allocated to each Container App replica (e.g. '1Gi')."
  type        = string
  default     = "1Gi"
}

variable "azure_container_image" {
  description = "Docker image for the agent swarm container."
  type        = string
  default     = "yieldswarm/agent-swarm:latest"
}

variable "azure_min_replicas" {
  description = "Minimum number of Container App replicas."
  type        = number
  default     = 1
}

variable "azure_max_replicas" {
  description = "Maximum number of Container App replicas."
  type        = number
  default     = 10
}

# ---------------------------------------------------------------------------
# DigitalOcean
# ---------------------------------------------------------------------------
variable "do_region" {
  description = "DigitalOcean region for Droplets and App Platform."
  type        = string
  default     = "nyc3"
}

variable "do_droplet_size" {
  description = "DigitalOcean Droplet size slug."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "do_droplet_image" {
  description = "DigitalOcean Droplet OS image slug."
  type        = string
  default     = "ubuntu-24-04-x64"
}

# ---------------------------------------------------------------------------
# Vultr
# ---------------------------------------------------------------------------
variable "vultr_region" {
  description = "Vultr region ID."
  type        = string
  default     = "ewr"
}

variable "vultr_plan" {
  description = "Vultr plan ID for the VPS."
  type        = string
  default     = "vc2-2c-4gb"
}

variable "vultr_os_id" {
  description = "Vultr OS ID (2136 = Ubuntu 24.04 LTS)."
  type        = number
  default     = 2136
}

# ---------------------------------------------------------------------------
# RunPod
# ---------------------------------------------------------------------------
variable "runpod_api_url" {
  description = "RunPod GraphQL API endpoint."
  type        = string
  default     = "https://api.runpod.io/graphql"
}

variable "runpod_gpu_type_id" {
  description = "RunPod GPU type ID (e.g. 'NVIDIA RTX A4000')."
  type        = string
  default     = "NVIDIA RTX A4000"
}

variable "runpod_pod_name" {
  description = "Name for the RunPod GPU pod."
  type        = string
  default     = "yieldswarm-gpu"
}

variable "runpod_container_disk_gb" {
  description = "Container disk size in GB for the RunPod pod."
  type        = number
  default     = 20
}

variable "runpod_volume_in_gb" {
  description = "Persistent volume size in GB for the RunPod pod."
  type        = number
  default     = 50
}

# ---------------------------------------------------------------------------
# Common tags
# ---------------------------------------------------------------------------
variable "tags" {
  description = "Tags to apply to all taggable resources."
  type        = map(string)
  default = {
    project     = "yieldswarm"
    environment = "prod"
    managed_by  = "terraform"
  }
}
