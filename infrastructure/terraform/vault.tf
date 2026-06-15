# =============================================================================
# Vault authentication + secret retrieval.
#
# The Terraform run authenticates against Vault using a short-lived AppRole
# token. Every provider credential is then read from KV v2 at apply time so
# nothing sensitive ever lives in tfvars files, env vars on disk, or state
# files outside Vault's audit log.
# =============================================================================

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace != "" ? var.vault_namespace : null

  # Skip the implicit child token; AppRole tokens are already scoped & short.
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# -----------------------------------------------------------------------------
# Secret reads. Each is a separate data source so Terraform's dependency graph
# only pulls what the enabled providers need.
# -----------------------------------------------------------------------------

data "vault_kv_secret_v2" "azure" {
  count = var.enabled_clouds.azure ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_root}/infra/azure"
}

data "vault_kv_secret_v2" "runpod" {
  count = var.enabled_clouds.runpod ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_root}/infra/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  count = var.enabled_clouds.vultr ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_root}/infra/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  count = var.enabled_clouds.digitalocean ? 1 : 0
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_root}/infra/digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  mount = var.vault_kv_mount
  name  = "${var.vault_secret_root}/rpc"
}

# Convenience locals so module code never indexes count[0] inline.
locals {
  azure_secret  = var.enabled_clouds.azure ? data.vault_kv_secret_v2.azure[0].data : {}
  runpod_secret = var.enabled_clouds.runpod ? data.vault_kv_secret_v2.runpod[0].data : {}
  vultr_secret  = var.enabled_clouds.vultr ? data.vault_kv_secret_v2.vultr[0].data : {}
  do_secret     = var.enabled_clouds.digitalocean ? data.vault_kv_secret_v2.digitalocean[0].data : {}
  rpc_secret    = data.vault_kv_secret_v2.rpc.data

  common_tags = {
    environment = var.environment
    managed_by  = "terraform"
    stack       = "yieldswarm"
    secret_src  = "vault"
  }
}
