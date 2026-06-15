terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.4"
    }
  }

  # Use the Vault transit-encrypted backend so state-at-rest can never be
  # read off disk without a Vault token. Configure your bucket below.
  backend "s3" {
    bucket  = "yieldswarm-tfstate"
    key     = "vault/server-config/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # dynamodb_table for state locking (set in backend.hcl during init)
  }
}
