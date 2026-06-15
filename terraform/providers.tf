# terraform/providers.tf
#
# Vault provider authenticates with AppRole. The role_id is non-secret and may
# come from terraform.tfvars or a CI variable. The secret_id MUST be unwrapped
# *before* terraform runs (response-wrapping is a one-shot operation and is
# performed by the operator/CI runner, not by Terraform itself).
#
# Required inputs (set via env or *.tfvars):
#   VAULT_ADDR                              -> var.vault_addr
#   TF_VAR_vault_role_id=<role_id>          -> var.vault_role_id
#   TF_VAR_vault_secret_id=<unwrapped sid>  -> var.vault_secret_id
#
# CI flow (see SECRETS.md §"CI auth"):
#   1. CI receives a one-shot wrap token from `issue-secret-id.sh`.
#   2. CI runs:  TF_VAR_vault_secret_id="$(vault unwrap -field=secret_id "$WRAP_TOKEN")"
#   3. CI runs:  terraform apply
#   4. The AppRole token issued to terraform is short-lived (see vault/scripts/bootstrap.sh).

provider "vault" {
  address          = var.vault_addr
  skip_child_token = true

  # vault provider ≥ 5.x uses the path-based auth_login block instead of the
  # legacy auth_login_approle helper. The result is identical.
  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# ---------------------------------------------------------------------------
# Cloud providers below are configured from credentials read by
# module.vault_secrets. Provider configurations can reference data sources,
# so this chain works: vault auth -> vault data sources -> provider config.
# ---------------------------------------------------------------------------

provider "azurerm" {
  features {}

  client_id       = module.vault_secrets.azure.client_id
  client_secret   = module.vault_secrets.azure.client_secret
  tenant_id       = module.vault_secrets.azure.tenant_id
  subscription_id = module.vault_secrets.azure.subscription_id
}

provider "vultr" {
  api_key     = module.vault_secrets.vultr.api_key
  rate_limit  = 1
  retry_limit = 3
}

provider "digitalocean" {
  token             = module.vault_secrets.digitalocean.token
  spaces_access_id  = module.vault_secrets.digitalocean.spaces_access_id
  spaces_secret_key = module.vault_secrets.digitalocean.spaces_secret_key
}
