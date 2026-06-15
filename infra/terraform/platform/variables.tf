variable "application_name" {
  description = "Application identifier used in Vault runtime paths."
  type        = string
  default     = "agentswarm"
}

variable "environment" {
  description = "Environment to read from Vault."
  type        = string
  default     = "prod"
}

variable "platform_mount_path" {
  description = "KV v2 mount that stores provider credentials."
  type        = string
  default     = "platform"
}

variable "runtime_mount_path" {
  description = "KV v2 mount that stores runtime application secrets."
  type        = string
  default     = "apps"
}
