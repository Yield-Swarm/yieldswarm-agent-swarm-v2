variable "vault_addr" {
  description = "HTTPS address for Vault (for example: https://vault.example.com:8200)."
  type        = string
}

variable "vault_token" {
  description = "Bootstrap/admin token for Terraform to configure Vault."
  type        = string
  sensitive   = true
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise namespace."
  type        = string
  default     = null
}

variable "cloud_mount_path" {
  description = "KV-v2 mount path for cloud provider credentials."
  type        = string
  default     = "cloud"
}

variable "rpc_mount_path" {
  description = "KV-v2 mount path for RPC credentials and endpoints."
  type        = string
  default     = "rpc"
}

variable "kubernetes_auth_path" {
  description = "Vault auth path for Kubernetes auth."
  type        = string
  default     = "kubernetes"
}

variable "akash_namespace" {
  description = "Kubernetes namespace used by the Akash workload."
  type        = string
  default     = "default"
}

variable "akash_service_accounts" {
  description = "Service accounts allowed to authenticate as Akash runtime."
  type        = list(string)
  default     = ["default"]
}

variable "terraform_policy_name" {
  description = "Policy name used by Terraform automation."
  type        = string
  default     = "terraform-cloud-read"
}

variable "akash_policy_name" {
  description = "Policy name used by the Akash runtime container."
  type        = string
  default     = "akash-runtime-read"
}

variable "terraform_approle_name" {
  description = "AppRole name used for Terraform automation."
  type        = string
  default     = "terraform-ci"
}

variable "read_runtime_secrets" {
  description = "When true, Terraform reads Azure/RunPod/Vultr/DO/RPC secrets from Vault."
  type        = bool
  default     = true
}

variable "cloud_bootstrap_secrets" {
  description = "Optional map of bootstrap secrets to write into cloud KV-v2 mount."
  type        = map(map(string))
  default     = {}
  sensitive   = true
}

variable "rpc_bootstrap_secrets" {
  description = "Optional map of bootstrap secrets to write into rpc KV-v2 mount."
  type        = map(map(string))
  default     = {}
  sensitive   = true
}
