# =============================================================================
# Remote state backend.
# CRITICAL: data sources that read Vault secrets persist their values into
# Terraform state. State MUST live in an encrypted, access-controlled backend
# — never on a laptop or in git. Azure Blob (with infrastructure encryption)
# is used here to align with the Azure integration. Configure the actual
# values at init time with `-backend-config` so nothing sensitive is committed.
#
#   terraform init \
#     -backend-config="resource_group_name=yieldswarm-tfstate" \
#     -backend-config="storage_account_name=yieldswarmtfstate" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=infra/terraform.tfstate"
# =============================================================================
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
