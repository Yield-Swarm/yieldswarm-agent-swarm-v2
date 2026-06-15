variable "vault_addr" {
  description = "HashiCorp Vault address used by Terraform and Odysseus workloads."
  type        = string
}

variable "vault_namespace" {
  description = "Optional Vault Enterprise namespace."
  type        = string
  default     = null
}

variable "runtime_secret_path" {
  description = "KV path containing Odysseus runtime secrets such as API keys and model host values."
  type        = string
  default     = "kv/data/yieldswarm/odysseus/runtime"
}

variable "deploy_secret_path" {
  description = "KV path containing deployment-only values such as image repository and Akash transaction settings."
  type        = string
  default     = "kv/data/yieldswarm/odysseus/deploy"
}

variable "runtime_policy_name" {
  description = "Vault policy name for Odysseus runtime secret reads."
  type        = string
  default     = "yieldswarm-odysseus-runtime"
}

variable "deploy_policy_name" {
  description = "Vault policy name for CI and production deployment secret reads."
  type        = string
  default     = "yieldswarm-odysseus-deploy"
}

variable "configure_github_actions_role" {
  description = "Create a Vault JWT role for GitHub Actions OIDC."
  type        = bool
  default     = true
}

variable "github_jwt_auth_backend" {
  description = "Vault JWT auth backend path for GitHub Actions."
  type        = string
  default     = "jwt"
}

variable "github_jwt_role" {
  description = "Vault role consumed by .github/workflows/build-odysseus.yml."
  type        = string
  default     = "yieldswarm-odysseus-github-actions"
}

variable "github_repository" {
  description = "GitHub repository claim allowed to assume the CI Vault role, for example org/repo."
  type        = string
}

variable "github_jwt_audience" {
  description = "Expected GitHub OIDC audience."
  type        = string
  default     = "https://github.com/hashicorp/vault-action"
}

variable "configure_runtime_jwt_role" {
  description = "Create a Vault JWT role for Odysseus runtime workloads."
  type        = bool
  default     = true
}

variable "runtime_jwt_auth_backend" {
  description = "Vault JWT auth backend path for runtime workloads."
  type        = string
  default     = "jwt"
}

variable "runtime_jwt_role" {
  description = "Vault role used by Akash and multi-cloud Odysseus workloads."
  type        = string
  default     = "yieldswarm-odysseus-runtime"
}

variable "runtime_jwt_audience" {
  description = "Expected JWT audience for runtime workload identity tokens."
  type        = string
  default     = "odysseus-runtime"
}

variable "runtime_bound_subject" {
  description = "Optional JWT subject claim for runtime workload identity binding."
  type        = string
  default     = null
}
