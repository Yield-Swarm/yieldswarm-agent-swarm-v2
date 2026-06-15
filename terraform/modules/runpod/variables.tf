variable "project"       { type = string }
variable "environment"   { type = string }
variable "agent_image"   { type = string }
variable "gpu_type"      { type = string }
variable "gpu_count"     { type = number }
variable "container_disk" { type = number }
variable "pod_count"     { type = number }
variable "vault_addr"    { type = string }

variable "vault_approle_role_id" {
  type = string
}

variable "vault_approle_secret_id" {
  type      = string
  sensitive = true
}

variable "network_volume_id" {
  type    = string
  default = ""
}
