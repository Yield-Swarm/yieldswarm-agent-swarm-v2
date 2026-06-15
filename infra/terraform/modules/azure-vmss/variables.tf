variable "name_prefix" {
  type = string
}

variable "unique_suffix" {
  type = string
}

variable "worker_count" {
  description = "Number of VMSS instances (workers) to run."
  type        = number
}

variable "location" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "source_image_id" {
  description = "Packer-built image resource ID. Empty = Ubuntu marketplace image."
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Existing resource group. Empty = create one."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  type = string
}

variable "worker_image" {
  type = string
}

variable "worker_provider" {
  type = string
}

variable "worker_env" {
  type = map(string)
}

variable "admin_username" {
  type    = string
  default = "swarm"
}

variable "tags" {
  type    = map(string)
  default = {}
}
