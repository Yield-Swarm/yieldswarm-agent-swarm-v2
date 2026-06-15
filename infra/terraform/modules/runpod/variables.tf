variable "enabled" {
  type    = bool
  default = true
}

variable "name" {
  type = string
}

variable "image_name" {
  type = string
}

variable "gpu_type_ids" {
  type = list(string)
}

variable "data_center_ids" {
  type = list(string)
}

variable "gpu_count" {
  type = number
}

variable "cloud_type" {
  type = string
}

variable "support_public_ip" {
  type = bool
}

variable "volume_in_gb" {
  type = number
}

variable "container_disk_in_gb" {
  type = number
}

variable "network_volume_in_gb" {
  type = number
}

variable "volume_mount_path" {
  type = string
}

variable "ports" {
  type = list(string)
}

variable "env" {
  type    = map(string)
  default = {}
}
