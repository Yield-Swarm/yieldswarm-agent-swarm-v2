# terraform/vault_secrets.tf
# Reads all cloud provider credentials and RPC secrets from Vault.
# These data sources are evaluated after the Vault provider authenticates
# (via VAULT_TOKEN set by vault-env.sh), and their values are passed to
# resource arguments — they are NEVER written to local files or state as plaintext.
#
# Terraform state is encrypted at rest; use a remote backend with server-side
# encryption (S3+KMS, GCS CMEK, Azure Blob with CMK) in production.

# ---------------------------------------------------------------------------
# Azure credentials
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "azure" {
  mount = "secret"
  name  = "azure/credentials"
}

locals {
  azure = data.vault_kv_secret_v2.azure.data
}

# ---------------------------------------------------------------------------
# RunPod credentials
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "runpod" {
  mount = "secret"
  name  = "runpod/credentials"
}

locals {
  runpod = data.vault_kv_secret_v2.runpod.data
}

# ---------------------------------------------------------------------------
# Vultr credentials
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "vultr" {
  mount = "secret"
  name  = "vultr/credentials"
}

locals {
  vultr_creds = data.vault_kv_secret_v2.vultr.data
}

# ---------------------------------------------------------------------------
# DigitalOcean credentials
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "digitalocean" {
  mount = "secret"
  name  = "digitalocean/credentials"
}

locals {
  do_creds = data.vault_kv_secret_v2.digitalocean.data
}

# ---------------------------------------------------------------------------
# Solana / Blockchain RPC secrets
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "rpc_solana" {
  mount = "secret"
  name  = "rpc/solana"
}

locals {
  rpc_solana = data.vault_kv_secret_v2.rpc_solana.data
}

# ---------------------------------------------------------------------------
# EVM / other-chain RPC secrets
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "rpc_evm" {
  mount = "secret"
  name  = "rpc/evm"
}

locals {
  rpc_evm = data.vault_kv_secret_v2.rpc_evm.data
}

# ---------------------------------------------------------------------------
# Agent master secrets (referenced by Container App / Droplet user-data)
# ---------------------------------------------------------------------------
data "vault_kv_secret_v2" "agents_master" {
  mount = "secret"
  name  = "agents/master"
}

locals {
  agents_master = data.vault_kv_secret_v2.agents_master.data
}
