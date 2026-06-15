variable "enabled" {
  type    = bool
  default = true
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "target_size" {
  type = number
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "source_image" {
  type = string
}

variable "startup_script" {
  type    = string
  default = null
}

variable "service_account_email" {
  type    = string
  default = null
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "enable_autoscaling" {
  type    = bool
  default = true
}

variable "min_replicas" {
  type = number
}

variable "max_replicas" {
  type = number
}

variable "cpu_target" {
  type = number
}
