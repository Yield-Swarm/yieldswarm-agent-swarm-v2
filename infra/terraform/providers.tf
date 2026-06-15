###############################################################################
# Provider configuration.
#
# Every provider is configured from variables so that no credentials live in
# source control. In the Helixchainprod workspace these are supplied as
# (sensitive) workspace variables / environment variables:
#
#   ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
#   GOOGLE_CREDENTIALS (or workload identity)
#   VULTR_API_KEY
#   RUNPOD_API_KEY
###############################################################################

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id != "" ? var.azure_subscription_id : null
  tenant_id       = var.azure_tenant_id != "" ? var.azure_tenant_id : null
  client_id       = var.azure_client_id != "" ? var.azure_client_id : null
  client_secret   = var.azure_client_secret != "" ? var.azure_client_secret : null

  # Avoid requiring broad RP-registration permissions in the workspace SP.
  resource_provider_registrations = "none"
}

provider "google" {
  project     = var.gcp_project_id != "" ? var.gcp_project_id : null
  region      = var.gcp_region
  credentials = var.gcp_credentials_json != "" ? var.gcp_credentials_json : null
}

provider "vultr" {
  api_key     = var.vultr_api_key
  rate_limit  = 700
  retry_limit = 3
}

provider "runpod" {
  api_key = var.runpod_api_key
}
