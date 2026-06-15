variable "project"          { type = string }
variable "environment"      { type = string }
variable "resource_group"   { type = string }
variable "location"         { type = string }
variable "agent_image"      { type = string }
variable "vault_addr"       { type = string }
variable "shard_count"      { type = number }
variable "agents_per_shard" { type = number }
variable "min_replicas"     { type = number }
variable "max_replicas"     { type = number }
variable "cpu"              { type = number }
variable "memory"           { type = string }

variable "vault_approle_role_id" {
  type      = string
}

variable "vault_approle_secret_id" {
  type      = string
  sensitive = true
}

variable "solana_rpc_url" {
  type      = string
  sensitive = true
}

variable "helius_api_key" {
  type      = string
  sensitive = true
}
