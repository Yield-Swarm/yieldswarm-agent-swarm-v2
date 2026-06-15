output "vault_secret_paths" {
  description = "Vault paths consumed by this Terraform stack. Secret values are intentionally never output."
  value = {
    azure        = "${local.vault_kv_mount}/${var.azure_secret_name}"
    runpod       = "${local.vault_kv_mount}/${var.runpod_secret_name}"
    vultr        = "${local.vault_kv_mount}/${var.vultr_secret_name}"
    digitalocean = "${local.vault_kv_mount}/${var.digitalocean_secret_name}"
    rpc          = "${local.vault_kv_mount}/${var.rpc_secret_name}"
  }
}

output "cloud_providers_configured_from_vault" {
  description = "Cloud providers whose Terraform credentials are sourced from Vault."
  value = [
    "azurerm",
    "runpod",
    "vultr",
    "digitalocean",
  ]
}

output "rpc_fields_consumed_from_vault" {
  description = "RPC field names read from Vault without exposing values."
  value = [
    "solana_rpc_url",
    "failover_rpc_list_json",
    "helius_api_key",
    "ethereum_rpc_url",
    "base_rpc_url",
    "polygon_rpc_url",
  ]
}
