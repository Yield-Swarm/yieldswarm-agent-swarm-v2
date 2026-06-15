variable "name_prefix" {
  type = string
}

variable "unique_suffix" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "project_id" {
  type    = string
  default = ""
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "gpu_type" {
  description = "Accelerator type (e.g. nvidia-tesla-t4). Empty = CPU only."
  type        = string
  default     = ""
}

variable "gpu_count" {
  type    = number
  default = 0
}

variable "source_image" {
  description = "Image self-link or family. Empty = Ubuntu 22.04 LTS family."
  type        = string
  default     = ""
}

variable "network" {
  type    = string
  default = "default"
}

variable "subnetwork" {
  type    = string
  default = ""
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

variable "ssh_username" {
  type    = string
  default = "swarm"
}

variable "labels" {
  type    = map(string)
  default = {}
}
