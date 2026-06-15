## vault.tf
## Single source of truth for credentials.  Every other provider in this root
## module receives its secrets through these data sources.  Nothing here is
## written to state in plaintext beyond the unavoidable provider config (and
## we mark every output sensitive so the CLI never prints them).

provider "vault" {
  address            = var.vault_address
  namespace          = var.vault_namespace
  skip_tls_verify    = var.vault_skip_tls_verify
  add_address_to_env = "true"

  # AppRole login - one of the two paths.  When `vault_secret_id_wrapped` is
  # set, the provider unwraps a single-use response-wrapping token; otherwise
  # it falls back to a plain secret_id.  Wrapped is strongly preferred.
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = coalesce(var.vault_secret_id, try(data.vault_generic_secret.unwrap[0].data["secret_id"], null))
    }
  }
}

# When a wrapped secret_id is supplied, unwrap it once via a transient
# provider config (no auth_login) and feed the result into the real provider.
provider "vault" {
  alias                  = "unwrap"
  address                = var.vault_address
  namespace              = var.vault_namespace
  skip_tls_verify        = var.vault_skip_tls_verify
  token                  = var.vault_secret_id_wrapped
  skip_get_vault_version = true
  skip_child_token       = true
}

data "vault_generic_secret" "unwrap" {
  provider = vault.unwrap
  count    = var.vault_secret_id_wrapped == null ? 0 : 1
  path     = "sys/wrapping/unwrap"
}

# --- Locals: per-secret paths, kept in one place for readability ----------
locals {
  base = "${var.vault_kv_mount}/yieldswarm/${var.environment}"

  paths = {
    azure        = "${local.base}/azure"
    runpod       = "${local.base}/runpod"
    vultr        = "${local.base}/vultr"
    digitalocean = "${local.base}/digitalocean"
    akash        = "${local.base}/akash"
    rpc_solana   = "${local.base}/rpc/solana"
    rpc_eth      = "${local.base}/rpc/eth"
    rpc_ton      = "${local.base}/rpc/ton"
    rpc_tao      = "${local.base}/rpc/tao"
  }
}

# --- KV v2 reads.  Each one is gated on its `enable_*` flag so a partial
# --- deployment doesn't need every secret to exist.

data "vault_kv_secret_v2" "azure" {
  count = var.enable_azure ? 1 : 0
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/azure"
}

data "vault_kv_secret_v2" "runpod" {
  count = var.enable_runpod ? 1 : 0
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  count = var.enable_vultr ? 1 : 0
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  count = var.enable_digitalocean ? 1 : 0
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/digitalocean"
}

# RPC secrets are always required - the application core depends on them.
data "vault_kv_secret_v2" "rpc_solana" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/rpc/solana"
}
data "vault_kv_secret_v2" "rpc_eth" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/rpc/eth"
}
data "vault_kv_secret_v2" "rpc_ton" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/rpc/ton"
}
data "vault_kv_secret_v2" "rpc_tao" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/${var.environment}/rpc/tao"
}

# Convenience locals - reading once, marked sensitive.
locals {
  azure_creds        = var.enable_azure ? data.vault_kv_secret_v2.azure[0].data : {}
  runpod_creds       = var.enable_runpod ? data.vault_kv_secret_v2.runpod[0].data : {}
  vultr_creds        = var.enable_vultr ? data.vault_kv_secret_v2.vultr[0].data : {}
  digitalocean_creds = var.enable_digitalocean ? data.vault_kv_secret_v2.digitalocean[0].data : {}

  rpc_secrets = {
    solana = data.vault_kv_secret_v2.rpc_solana.data
    eth    = data.vault_kv_secret_v2.rpc_eth.data
    ton    = data.vault_kv_secret_v2.rpc_ton.data
    tao    = data.vault_kv_secret_v2.rpc_tao.data
  }
}
