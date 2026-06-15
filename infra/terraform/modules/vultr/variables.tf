variable "name_prefix" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "region" {
  type = string
}

variable "plan" {
  type = string
}

variable "os_id" {
  type    = number
  default = 1743
}

variable "snapshot_id" {
  description = "Packer-built snapshot ID. Empty = boot from os_id."
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

variable "tags" {
  type    = map(string)
  default = {}
}
