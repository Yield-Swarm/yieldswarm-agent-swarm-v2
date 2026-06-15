###############################################################################
# Provider & Terraform version constraints for the multi-cloud worker fallback.
#
# These pins are intentionally conservative so that `terraform init` resolves a
# reproducible set of plugins for the Helixchainprod workspace.
###############################################################################

terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }

    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.31"
    }

    runpod = {
      source  = "decentralized-infrastructure/runpod"
      version = "~> 1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
