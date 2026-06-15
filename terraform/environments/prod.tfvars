# Example tfvars — NO SECRETS. AppRole credentials come from CI/CD env vars.
#
# export TF_VAR_vault_role_id="..."
# export TF_VAR_vault_secret_id="..."
# export VAULT_ADDR="https://vault.yieldswarm.internal:8200"
#
# terraform plan -var-file=environments/prod.tfvars

environment = "prod"

# Optional overrides (defaults pulled from Vault azure secret):
# azure_resource_group_name = "yieldswarm-prod"
# azure_location            = "eastus"
