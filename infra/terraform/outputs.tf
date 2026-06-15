# Outputs deliberately expose only NON-SENSITIVE confirmation that each provider
# was wired to a Vault-sourced credential. Secret values are never output.

output "credentials_sourced_from_vault" {
  description = "Per-provider confirmation that a non-empty credential was read from Vault. Only presence (boolean) is exposed, never values."
  value = {
    azure        = nonsensitive(try(local.azure["arm_client_id"], "") != "")
    runpod       = nonsensitive(try(local.runpod["api_key"], "") != "")
    vultr        = nonsensitive(try(local.vultr["api_key"], "") != "")
    digitalocean = nonsensitive(try(local.digitalocean["token"], "") != "")
    rpc          = nonsensitive(try(local.rpc["SOLANA_RPC_URL"], "") != "")
  }
}

output "vault_secret_paths" {
  description = "The Vault KV v2 paths Terraform reads credentials from."
  value = {
    azure        = "${var.vault_kv_mount}/yieldswarm/cloud/azure"
    runpod       = "${var.vault_kv_mount}/yieldswarm/cloud/runpod"
    vultr        = "${var.vault_kv_mount}/yieldswarm/cloud/vultr"
    digitalocean = "${var.vault_kv_mount}/yieldswarm/cloud/digitalocean"
    rpc          = "${var.vault_kv_mount}/yieldswarm/rpc"
  }
}
