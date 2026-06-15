# terraform/modules/azure/main.tf
#
# This module does NOT configure the azurerm provider — that happens at the
# root in terraform/providers.tf so the module is compatible with `count`.
# The root provider is configured from var.credentials at composition time.

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
