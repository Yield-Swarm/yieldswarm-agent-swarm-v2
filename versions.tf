terraform {
  required_version = ">= 1.6.0"

  cloud {
    organization = "HelixChainProd"

    workspaces {
      name = "Helixchainprod"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.114.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
  }
}
