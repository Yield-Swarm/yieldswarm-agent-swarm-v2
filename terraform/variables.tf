# ---------------------------------------------------------------------------
# terraform/variables.tf
# Non-secret configuration variables.
# These can be committed safely; secrets come from Vault (secrets.tf).
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------
variable "environment" {
  description = "Deployment environment: prod | staging | dev"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be 'prod', 'staging', or 'dev'."
  }
}

variable "project" {
  description = "Project name used as a prefix for all resource names."
  type        = string
  default     = "agentswarm"
}

variable "vault_addr" {
  description = "Vault server address, e.g. https://vault.yourdomain.com:8200"
  type        = string
  # Do NOT set a default here — force explicit configuration.
}

variable "agent_image" {
  description = "Docker image for AgentSwarm containers."
  type        = string
  default     = "ghcr.io/yieldswarm/agentswarm-os:latest"
}

# ---------------------------------------------------------------------------
# Agent sharding
# ---------------------------------------------------------------------------
variable "total_agents" {
  description = "Total number of agents to deploy."
  type        = number
  default     = 10080
}

variable "agents_per_shard" {
  description = "Agents per container shard."
  type        = number
  default     = 84
}

variable "shard_count" {
  description = "Number of container shards (total_agents / agents_per_shard)."
  type        = number
  default     = 120
}

# ---------------------------------------------------------------------------
# Azure module
# ---------------------------------------------------------------------------
variable "azure_location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "azure_container_cpu" {
  description = "CPU units per agent container in Azure Container Apps."
  type        = number
  default     = 0.5
}

variable "azure_container_memory" {
  description = "Memory per agent container in Azure Container Apps (e.g. '1Gi')."
  type        = string
  default     = "1Gi"
}

variable "azure_min_replicas" {
  description = "Minimum number of Azure container replicas per shard app."
  type        = number
  default     = 1
}

variable "azure_max_replicas" {
  description = "Maximum number of Azure container replicas per shard app."
  type        = number
  default     = 5
}

# ---------------------------------------------------------------------------
# RunPod module
# ---------------------------------------------------------------------------
variable "runpod_gpu_type" {
  description = "RunPod GPU type for inference pods (e.g. NVIDIA GeForce RTX 4090)."
  type        = string
  default     = "NVIDIA GeForce RTX 4090"
}

variable "runpod_gpu_count" {
  description = "Number of GPUs per RunPod instance."
  type        = number
  default     = 1
}

variable "runpod_container_disk_size" {
  description = "RunPod container disk size in GB."
  type        = number
  default     = 50
}

variable "runpod_pod_count" {
  description = "Number of RunPod GPU pods to provision."
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------------
# Vultr module
# ---------------------------------------------------------------------------
variable "vultr_region" {
  description = "Vultr region code (e.g. ewr = New Jersey)."
  type        = string
  default     = "ewr"
}

variable "vultr_plan" {
  description = "Vultr instance plan slug."
  type        = string
  default     = "vc2-2c-4gb"
}

variable "vultr_os_id" {
  description = "Vultr OS image ID (387 = Debian 11 x64)."
  type        = number
  default     = 387
}

variable "vultr_instance_count" {
  description = "Number of Vultr VPS instances."
  type        = number
  default     = 3
}

# ---------------------------------------------------------------------------
# DigitalOcean module
# ---------------------------------------------------------------------------
variable "do_region" {
  description = "DigitalOcean region (e.g. nyc3)."
  type        = string
  default     = "nyc3"
}

variable "do_droplet_size" {
  description = "DigitalOcean Droplet size slug."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "do_droplet_count" {
  description = "Number of DigitalOcean Droplets."
  type        = number
  default     = 3
}

variable "do_spaces_region" {
  description = "DigitalOcean Spaces region."
  type        = string
  default     = "nyc3"
}

variable "do_db_node_count" {
  description = "Number of nodes in the managed PostgreSQL cluster."
  type        = number
  default     = 1
}
