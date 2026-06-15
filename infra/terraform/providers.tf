provider "azurerm" {
  features {}

  subscription_id            = var.azure_subscription_id
  tenant_id                  = var.azure_tenant_id
  client_id                  = var.azure_client_id
  client_secret              = var.azure_client_secret
  skip_provider_registration = true
}

provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = var.gcp_credentials_json
}

provider "runpod" {
  api_key = var.runpod_api_key
}

provider "vultr" {
  api_key = var.vultr_api_key
}
