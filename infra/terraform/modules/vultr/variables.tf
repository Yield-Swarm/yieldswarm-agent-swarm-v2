variable "enabled" {
  type    = bool
  default = true
}

variable "instance_count" {
  type = number
}

variable "label" {
  type = string
}

variable "hostname" {
  type = string
}

variable "region" {
  type = string
}

variable "plan" {
  type = string
}

variable "os_id" {
  type = string
}

variable "image_id" {
  type    = string
  default = null
}

variable "ssh_key_ids" {
  type    = list(string)
  default = []
}

variable "user_data" {
  type    = string
  default = null
}

variable "enable_ipv6" {
  type = bool
}

variable "backups" {
  type = string
}

variable "tags" {
  type    = list(string)
  default = []
}
