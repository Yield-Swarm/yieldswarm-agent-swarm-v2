###############################################################################
# Shared Packer input variables for the AgentSwarm worker images.
###############################################################################

variable "image_name" {
  type    = string
  default = "agentswarm-worker"
}

variable "image_version" {
  type    = string
  default = "1-0-0"
}

variable "worker_image" {
  description = "Container image baked into the VM image."
  type        = string
  default     = "ghcr.io/yieldswarm/agentswarm-worker:latest"
}

variable "enable_gpu" {
  description = "Install the NVIDIA driver + container toolkit."
  type        = bool
  default     = false
}

# --- Azure -------------------------------------------------------------------
variable "azure_subscription_id" {
  type    = string
  default = env("ARM_SUBSCRIPTION_ID")
}

variable "azure_tenant_id" {
  type    = string
  default = env("ARM_TENANT_ID")
}

variable "azure_client_id" {
  type    = string
  default = env("ARM_CLIENT_ID")
}

variable "azure_client_secret" {
  type      = string
  default   = env("ARM_CLIENT_SECRET")
  sensitive = true
}

variable "azure_resource_group" {
  description = "Resource group that will hold the managed image."
  type        = string
  default     = "yieldswarm-images"
}

variable "azure_location" {
  type    = string
  default = "eastus"
}

variable "azure_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

# --- GCP ---------------------------------------------------------------------
variable "gcp_project_id" {
  type    = string
  default = env("GOOGLE_PROJECT")
}

variable "gcp_zone" {
  type    = string
  default = "us-central1-a"
}

variable "gcp_machine_type" {
  type    = string
  default = "e2-standard-4"
}

# --- Vultr -------------------------------------------------------------------
variable "vultr_api_key" {
  type      = string
  default   = env("VULTR_API_KEY")
  sensitive = true
}

variable "vultr_region" {
  type    = string
  default = "ewr"
}

variable "vultr_plan" {
  type    = string
  default = "vc2-4c-8gb"
}

variable "vultr_os_id" {
  description = "Base OS for the build instance (1743 = Ubuntu 22.04 x64)."
  type        = number
  default     = 1743
}
