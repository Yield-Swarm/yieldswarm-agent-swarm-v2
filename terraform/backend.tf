# terraform/backend.tf
#
# Backend uses partial configuration — concrete values come from
# `terraform init -backend-config=envs/<env>/backend.hcl`. This keeps the
# same module tree usable across staging/prod without duplicate definitions.

terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
