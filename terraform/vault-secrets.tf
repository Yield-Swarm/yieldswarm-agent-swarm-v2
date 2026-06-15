# Pull all cloud and RPC secrets from Vault KV v2 at plan/apply time.
# Paths are defined in infra/vault/scripts/bootstrap.sh and documented in SECRETS.md.

data "vault_kv_secret_v2" "azure" {
  mount = "yieldswarm"
  name  = "azure"
}

data "vault_kv_secret_v2" "runpod" {
  mount = "yieldswarm"
  name  = "runpod"
}

data "vault_kv_secret_v2" "vultr" {
  mount = "yieldswarm"
  name  = "vultr"
}

data "vault_kv_secret_v2" "digitalocean" {
  mount = "yieldswarm"
  name  = "digitalocean"
}

data "vault_kv_secret_v2" "rpc" {
  mount = "yieldswarm"
  name  = "rpc"
}

data "vault_kv_secret_v2" "akash" {
  mount = "yieldswarm"
  name  = "akash"
}

locals {
  azure_secrets = data.vault_kv_secret_v2.azure.data
  runpod_secrets = data.vault_kv_secret_v2.runpod.data
  vultr_secrets = data.vault_kv_secret_v2.vultr.data
  do_secrets = data.vault_kv_secret_v2.digitalocean.data
  rpc_secrets = data.vault_kv_secret_v2.rpc.data
  akash_secrets = data.vault_kv_secret_v2.akash.data

  failover_rpc_list = try(jsondecode(local.rpc_secrets.failover_rpc_list), [])
  gpu_cluster_keys  = try(jsondecode(local.akash_secrets.gpu_cluster_keys), [])

  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    secrets_via = "vault"
  }
}
