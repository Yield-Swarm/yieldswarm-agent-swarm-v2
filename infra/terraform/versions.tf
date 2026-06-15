terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.21"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
    }
    # No official RunPod provider exists; we drive the RunPod GraphQL API
    # through the generic REST provider so credentials still come from
    # Vault and state is tracked the same way as every other resource.
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.20"
    }
  }

  # Remote state in Azure Storage. The container is encrypted with a
  # customer-managed key and access is restricted to the apn-terraform
  # service principal that holds the matching Vault role.
  backend "azurerm" {
    # All values are injected by the CI runner via `terraform init -backend-config=...`.
    # The backend never reads provider credentials from local files.
    use_oidc = true
  }
}
