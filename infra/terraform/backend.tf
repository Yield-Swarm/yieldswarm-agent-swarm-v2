# =============================================================================
# Remote state backend.
#
# The state file holds the LAST-READ values of every Vault data source - so
# even though credentials are NOT inlined, anything that travels through
# Terraform's plan-time data graph IS persisted in state. Encrypt at rest
# with server-side AES-256, restrict access to the terraform-deploy SP only,
# and enable blob versioning.
#
# Switch the backend stanza below for your environment. Default = Azure
# Blob Storage; example HCP Terraform / S3 / GCS stanzas are commented out.
# =============================================================================

terraform {
  backend "azurerm" {
    resource_group_name  = "yieldswarm-tfstate"
    storage_account_name = "yieldswarmtfstate"
    container_name       = "prod"
    key                  = "agentswarm-os.tfstate"
    use_oidc             = true
  }

  # backend "s3" {
  #   bucket         = "yieldswarm-tfstate"
  #   key            = "agentswarm-os/prod/terraform.tfstate"
  #   region         = "us-east-2"
  #   encrypt        = true
  #   kms_key_id     = "alias/yieldswarm-tfstate"
  #   dynamodb_table = "yieldswarm-tfstate-lock"
  # }

  # backend "remote" {
  #   organization = "yieldswarm"
  #   workspaces {
  #     name = "agentswarm-os-prod"
  #   }
  # }
}
