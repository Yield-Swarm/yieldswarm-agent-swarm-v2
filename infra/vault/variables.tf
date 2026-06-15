variable "vault_addr" {
  description = "Vault cluster address. Prefer VAULT_ADDR in CI and shells."
  type        = string
  default     = null
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace. Leave null for OSS Vault."
  type        = string
  default     = null
}

variable "kv_mount_path" {
  description = "Path for the KV v2 secrets engine that stores provider and runtime secrets."
  type        = string
  default     = "secret"
}

variable "transit_mount_path" {
  description = "Path for the Transit secrets engine used for runtime cryptographic operations."
  type        = string
  default     = "transit"
}

variable "terraform_secret_paths" {
  description = "KV v2 logical secret paths Terraform is allowed to read."
  type        = list(string)
  default = [
    "terraform/azure",
    "terraform/digitalocean",
    "terraform/runpod",
    "terraform/vultr",
    "terraform/rpc",
  ]
}

variable "akash_runtime_secret_paths" {
  description = "KV v2 logical secret paths Akash workloads are allowed to read."
  type        = list(string)
  default = [
    "runtime/akash",
    "terraform/rpc",
  ]
}
