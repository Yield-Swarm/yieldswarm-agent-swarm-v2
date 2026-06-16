variable "tf_cloud_organization" {
  description = "Terraform Cloud organization (documented in terraform.tfvars.example)."
  type        = string
  default     = "HelixChainProd"
}

variable "tf_workspace" {
  description = "Terraform Cloud workspace (documented in terraform.tfvars.example)."
  type        = string
  default     = "Helixchainprod"
}

variable "akash_node" {
  description = "Akash RPC endpoint."
  type        = string
  default     = "https://rpc.akashnet.net:443"
}

variable "akash_chain_id" {
  description = "Akash chain id."
  type        = string
  default     = "akashnet-2"
}

variable "akash_key_name" {
  description = "Akash key name used by scripts/akash-deploy.sh."
  type        = string
  default     = "yieldswarm-admin"
}

variable "akash_gpu_model_hint" {
  description = "Hint used for provider selection when requesting GPUs."
  type        = string
  default     = "rtx3090"
}

variable "enable_azure_fallback" {
  description = "If true, create an Azure Linux VMSS fallback stack."
  type        = bool
  default     = true
}

variable "azure_subscription_id" {
  description = "Azure subscription id."
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure tenant id."
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_client_id" {
  description = "Azure service principal client id."
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure service principal client secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_location" {
  description = "Azure region for fallback resources."
  type        = string
  default     = "eastus"
}

variable "azure_resource_group_name" {
  description = "Azure resource group name for fallback."
  type        = string
  default     = "yieldswarm-fallback-rg"
}

variable "azure_vmss_name" {
  description = "Azure VMSS name for fallback workers."
  type        = string
  default     = "yieldswarm-fallback-vmss"
}

variable "azure_vm_size" {
  description = "Azure VM size for fallback workers."
  type        = string
  default     = "Standard_NC6s_v3"
}

variable "azure_instance_count" {
  description = "Number of fallback instances to launch."
  type        = number
  default     = 1
}

variable "azure_admin_username" {
  description = "Linux admin username for VMSS nodes."
  type        = string
  default     = "yieldswarm"
}

variable "azure_admin_ssh_public_key" {
  description = "Public SSH key used for VMSS access."
  type        = string
  default     = "ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY"
}

variable "runpod_api_key" {
  description = "Reserved for future RunPod fallback integration."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vultr_api_key" {
  description = "Reserved for future Vultr fallback integration."
  type        = string
  default     = ""
  sensitive   = true
}

variable "digitalocean_token" {
  description = "Reserved for future DigitalOcean fallback integration."
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_project_id" {
  description = "Reserved for future GCP fallback integration."
  type        = string
  default     = ""
}

variable "gcp_service_account_json" {
  description = "Reserved for future GCP fallback integration."
  type        = string
  default     = ""
  sensitive   = true
}
