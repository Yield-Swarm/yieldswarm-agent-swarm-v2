variable "admin_ssh_public_key" {
  description = "SSH public key for yieldswarm admin user. Inject via Vault / TF_VAR — never commit."
  type        = string
  sensitive   = true
}

variable "admin_username" {
  type    = string
  default = "yieldswarm"
}

variable "azure_prod_location" {
  type    = string
  default = "Australia East"
}

variable "azure_backup_location" {
  type    = string
  default = "Japan East"
}

variable "azure_dr_location" {
  type    = string
  default = "Indonesia Central"
}

variable "primary_vm_size" {
  type    = string
  default = "Standard_NV8as_v4"
}

variable "cosmos_account_name" {
  type    = string
  default = "ysmdbazcosmos"
}

variable "agent_count_total" {
  type    = number
  default = 10080
}

variable "cron_shard_count" {
  type    = number
  default = 120
}

variable "agents_per_shard" {
  type    = number
  default = 84
}
