variable "project"       { type = string }
variable "environment"   { type = string }
variable "agent_image"   { type = string }
variable "region"        { type = string }
variable "droplet_size"  { type = string }
variable "droplet_count" { type = number }
variable "spaces_region" { type = string }
variable "db_node_count" { type = number }
variable "vault_addr"    { type = string }

variable "vault_approle_role_id" {
  type = string
}

variable "vault_approle_secret_id" {
  type      = string
  sensitive = true
}
