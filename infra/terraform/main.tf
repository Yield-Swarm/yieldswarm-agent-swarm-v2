# Infrastructure resources go here. All five providers (azurerm, runpod, vultr,
# digitalocean) and the RPC endpoints are already wired to Vault-sourced
# credentials in providers.tf / vault.tf, so resources can consume them
# directly without any plaintext credentials in this codebase.
#
# Examples are feature-flagged off by default so that `terraform init/validate`
# is side-effect free. Flip the corresponding variable to provision real infra.
#
# Example — a DigitalOcean project (uncomment and set enable flag):
#
#   resource "digitalocean_project" "yieldswarm" {
#     count       = var.enable_digitalocean_example ? 1 : 0
#     name        = "yieldswarm"
#     description = "YieldSwarm AgentSwarm OS"
#     purpose     = "Web Application"
#     environment = "Production"
#   }
#
# Example — passing an RPC endpoint sourced from Vault into a resource:
#
#   resource "vultr_instance" "rpc_worker" {
#     count    = var.enable_vultr_example ? 1 : 0
#     region   = "ewr"
#     plan     = "vc2-1c-1gb"
#     os_id    = 1743
#     label    = "rpc-worker"
#     user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
#       solana_rpc_url = local.rpc["SOLANA_RPC_URL"]
#     })
#   }

# Lightweight, offline-friendly sanity checks that fail fast (at plan time) if a
# required credential was never seeded into Vault. These never expose values.
check "required_cloud_credentials_present" {
  assert {
    condition     = try(local.azure["arm_client_id"], "") != ""
    error_message = "Azure credentials missing from Vault at ${var.vault_kv_mount}/yieldswarm/cloud/azure. Run infra/vault/seed-secrets.sh."
  }
  assert {
    condition     = try(local.runpod["api_key"], "") != ""
    error_message = "RunPod api_key missing from Vault at ${var.vault_kv_mount}/yieldswarm/cloud/runpod."
  }
  assert {
    condition     = try(local.vultr["api_key"], "") != ""
    error_message = "Vultr api_key missing from Vault at ${var.vault_kv_mount}/yieldswarm/cloud/vultr."
  }
  assert {
    condition     = try(local.digitalocean["token"], "") != ""
    error_message = "DigitalOcean token missing from Vault at ${var.vault_kv_mount}/yieldswarm/cloud/digitalocean."
  }
  assert {
    condition     = try(local.rpc["SOLANA_RPC_URL"], "") != ""
    error_message = "SOLANA_RPC_URL missing from Vault at ${var.vault_kv_mount}/yieldswarm/rpc."
  }
}
