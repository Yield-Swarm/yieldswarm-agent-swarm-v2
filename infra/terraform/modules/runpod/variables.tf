variable "name_prefix" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "worker_image" {
  description = "Container image the pod runs (the AgentSwarm worker)."
  type        = string
}

variable "gpu_type_ids" {
  type = list(string)
}

variable "gpu_count" {
  type    = number
  default = 1
}

variable "data_center_ids" {
  type    = list(string)
  default = []
}

variable "cloud_type" {
  description = "SECURE or COMMUNITY."
  type        = string
  default     = "COMMUNITY"
}

variable "container_disk_in_gb" {
  type    = number
  default = 40
}

variable "volume_in_gb" {
  type    = number
  default = 40
}

variable "worker_env" {
  type = map(string)
}

variable "ports" {
  type    = list(string)
  default = ["22/tcp"]
}
