variable "enabled" {
  type    = bool
  default = true
}

variable "create_resource_group" {
  type    = bool
  default = true
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vmss_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "sku" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "admin_username" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "source_image_id" {
  type = string
}

variable "custom_data" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
