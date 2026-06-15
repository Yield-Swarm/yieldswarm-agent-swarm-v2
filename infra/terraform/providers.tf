# ---------------------------------------------------------------------------
# Vault provider.
#
# Authentication uses the AppRole pair supplied via TF_VAR_vault_role_id
# / TF_VAR_vault_secret_id. The CI runner reads these from on-disk files
# (see step 4a of SECRETS.md), exports them with `set -a`, runs the
# plan/apply, and unsets them again. The provider exchanges them for a
# 20-minute token bound to apn-terraform-read and revokes that token on
# exit. No long-lived Vault token ever lives on disk inside the CI box.
# ---------------------------------------------------------------------------
provider "vault" {
  address               = var.vault_address
  namespace             = var.vault_namespace != "" ? var.vault_namespace : null
  skip_child_token      = false
  max_lease_ttl_seconds = 1200

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# ---------------------------------------------------------------------------
# Single fetch point for every provider credential. Downstream provider
# blocks pull from these data sources; nothing else in the repo reads
# secrets directly.
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_prefix}/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_prefix}/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_prefix}/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_prefix}/digitalocean"
}

# RPC secrets are loaded per-chain. Adding a chain = adding a `for_each`
# entry, no policy or module change required.
locals {
  rpc_chains = toset([
    "solana",
    "eth",
    "ton",
    "tao",
    "helix",
    "zec",
  ])
}

data "vault_kv_secret_v2" "rpc" {
  for_each = local.rpc_chains
  mount    = var.vault_kv_mount
  name     = "${var.vault_secret_prefix}/rpc/${each.key}"
}

# ---------------------------------------------------------------------------
# Cloud provider blocks. Every credential reference flows from a Vault
# data source above; provider blocks contain no literal secrets.
# ---------------------------------------------------------------------------
provider "azurerm" {
  features {}
  subscription_id = data.vault_kv_secret_v2.azure.data["subscription_id"]
  tenant_id       = data.vault_kv_secret_v2.azure.data["tenant_id"]
  client_id       = data.vault_kv_secret_v2.azure.data["client_id"]
  client_secret   = data.vault_kv_secret_v2.azure.data["client_secret"]
}

provider "vultr" {
  api_key     = data.vault_kv_secret_v2.vultr.data["api_key"]
  rate_limit  = 700
  retry_limit = 3
}

provider "digitalocean" {
  token             = data.vault_kv_secret_v2.digitalocean.data["token"]
  spaces_access_id  = try(data.vault_kv_secret_v2.digitalocean.data["spaces_access_id"], null)
  spaces_secret_key = try(data.vault_kv_secret_v2.digitalocean.data["spaces_secret_key"], null)
}

# RunPod has no first-party Terraform provider; the generic REST provider
# is the canonical workaround documented by HashiCorp partners. We point
# it at the RunPod GraphQL endpoint with a bearer token sourced from
# Vault. All RunPod resources live in modules/runpod and call the REST
# API through this provider alias.
provider "restapi" {
  alias                = "runpod"
  uri                  = "https://api.runpod.io/graphql"
  write_returns_object = true
  debug                = false

  headers = {
    Authorization = "Bearer ${data.vault_kv_secret_v2.runpod.data["api_key"]}"
    Content-Type  = "application/json"
  }
}
