# =============================================================================
# Vault provider + secret data sources.
# The provider authenticates with the 'terraform-provisioner' AppRole when a
# role_id/secret_id pair is supplied; otherwise it uses VAULT_TOKEN from the
# environment. Every cloud-provider credential below is read here and consumed
# by the corresponding provider block in providers.tf.
# =============================================================================

provider "vault" {
  address          = var.vault_address # falls back to VAULT_ADDR
  namespace        = var.vault_namespace
  skip_child_token = true

  # AppRole login using the 'terraform-provisioner' role. Supply role_id and
  # secret_id via TF_VAR_vault_approle_* in CI (short-TTL, single-use). See
  # SECRETS.md section 4 for the exact commands that mint these.
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_approle_role_id
      secret_id = var.vault_approle_secret_id
    }
  }
}

# --- Cloud provider credentials --------------------------------------------
data "vault_kv_secret_v2" "azure" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/cloud/digitalocean"
}

# --- RPC / blockchain endpoints --------------------------------------------
data "vault_kv_secret_v2" "rpc_solana" {
  mount = var.vault_kv_mount
  name  = "yieldswarm/rpc/solana"
}

locals {
  azure_creds        = data.vault_kv_secret_v2.azure.data
  runpod_creds       = data.vault_kv_secret_v2.runpod.data
  vultr_creds        = data.vault_kv_secret_v2.vultr.data
  digitalocean_creds = data.vault_kv_secret_v2.digitalocean.data
  rpc_solana         = data.vault_kv_secret_v2.rpc_solana.data
}
