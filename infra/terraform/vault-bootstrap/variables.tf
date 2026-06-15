variable "vault_addr" {
  description = "Vault HTTP(S) address."
  type        = string
}

variable "vault_token" {
  description = "Administrative Vault token used to bootstrap auth, policies, and mounts."
  type        = string
  sensitive   = true
}

variable "kv_mount_path" {
  description = "KVv2 mount path used for platform secrets."
  type        = string
  default     = "kv"
}

variable "approle_path" {
  description = "Auth path where AppRole is enabled."
  type        = string
  default     = "approle"
}

variable "terraform_role_name" {
  description = "AppRole name for Terraform automation."
  type        = string
  default     = "terraform-reader"
}

variable "akash_role_name" {
  description = "AppRole name for the Akash runtime workload."
  type        = string
  default     = "akash-runtime"
}

variable "akash_token_bound_cidrs" {
  description = "Optional CIDR restrictions for Akash runtime tokens."
  type        = list(string)
  default     = []
}
