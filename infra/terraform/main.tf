locals {
  missing_secret_keys = compact([
    local.azure_subscription_id == null ? "terraform/azure.subscription_id" : null,
    local.azure_client_id == null ? "terraform/azure.client_id" : null,
    local.azure_client_secret == null ? "terraform/azure.client_secret" : null,
    local.azure_tenant_id == null ? "terraform/azure.tenant_id" : null,
    local.runpod_api_key == null ? "terraform/runpod.api_key" : null,
    local.vultr_api_key == null ? "terraform/vultr.api_key" : null,
    local.do_token == null ? "terraform/digitalocean.token" : null,
    local.rpc_primary_url == null ? "terraform/rpc.primary_url" : null,
    local.rpc_backup_url == null ? "terraform/rpc.backup_url" : null,
  ])
}

check "vault_secrets_are_present" {
  assert {
    condition     = length(local.missing_secret_keys) == 0
    error_message = "Vault is missing required secrets: ${join(", ", local.missing_secret_keys)}"
  }
}
