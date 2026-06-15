# Vault authentication via AppRole (production) or token (local dev).
# Set TF_VAR_vault_role_id / TF_VAR_vault_secret_id in CI, or use env:
#   VAULT_ROLE_ID, VAULT_SECRET_ID

variable "vault_role_id" {
  description = "AppRole role ID for Terraform."
  type        = string
  sensitive   = true
  default     = null
}

variable "vault_secret_id" {
  description = "AppRole secret ID for Terraform."
  type        = string
  sensitive   = true
  default     = null
}

provider "vault" {
  # VAULT_ADDR and VAULT_TOKEN env vars are read automatically when set.
  address         = var.vault_addr
  skip_tls_verify = var.vault_skip_tls_verify

  dynamic "auth_login" {
    for_each = var.vault_role_id != null && var.vault_secret_id != null ? [1] : []
    content {
      path = "auth/approle/login"
      parameters = {
        role_id   = var.vault_role_id
        secret_id = var.vault_secret_id
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Secret data sources — all cloud credentials pulled from Vault at plan/apply
# ---------------------------------------------------------------------------

data "vault_kv_secret_v2" "azure" {
  mount = "secret"
  name  = "yieldswarm/azure/credentials"
}

data "vault_kv_secret_v2" "runpod" {
  mount = "secret"
  name  = "yieldswarm/runpod/api"
}

data "vault_kv_secret_v2" "vultr" {
  mount = "secret"
  name  = "yieldswarm/vultr/api"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = "secret"
  name  = "yieldswarm/digitalocean/api"
}

data "vault_kv_secret_v2" "rpc_solana" {
  mount = "secret"
  name  = "yieldswarm/rpc/solana"
}

data "vault_kv_secret_v2" "rpc_failover" {
  mount = "secret"
  name  = "yieldswarm/rpc/failover"
}

locals {
  azure_creds = data.vault_kv_secret_v2.azure.data
  runpod_creds = data.vault_kv_secret_v2.runpod.data
  vultr_creds  = data.vault_kv_secret_v2.vultr.data
  do_creds     = data.vault_kv_secret_v2.digitalocean.data
  rpc_solana   = data.vault_kv_secret_v2.rpc_solana.data
  rpc_failover = data.vault_kv_secret_v2.rpc_failover.data

  solana_rpc_url    = local.rpc_solana["primary_url"]
  failover_rpc_list = jsondecode(local.rpc_failover["endpoints"])
}
