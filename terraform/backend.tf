# ---------------------------------------------------------------------------
# terraform/backend.tf
# Remote state configuration.
#
# Option A (default): Terraform Cloud / HCP Terraform — recommended for teams.
# Option B: Azure Blob Storage — good if Azure is your primary cloud.
# Option C: DigitalOcean Spaces — S3-compatible, lightweight.
#
# Uncomment exactly ONE backend block. Keep the others commented.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Option A: HCP Terraform (Terraform Cloud)
# ---------------------------------------------------------------------------
# terraform {
#   cloud {
#     organization = "your-org-name"
#     workspaces {
#       name = "agentswarm-prod"
#     }
#   }
# }

# ---------------------------------------------------------------------------
# Option B: Azure Blob Storage
# Credentials come from Azure provider env vars (ARM_*) or Managed Identity.
# Create the storage account and container before running `terraform init`.
# ---------------------------------------------------------------------------
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "agentswarm-tfstate-rg"
#     storage_account_name = "agentswarmtfstate"
#     container_name       = "tfstate"
#     key                  = "agentswarm.prod.tfstate"
#   }
# }

# ---------------------------------------------------------------------------
# Option C: DigitalOcean Spaces (S3-compatible)
# Set AWS_ACCESS_KEY_ID=<spaces_access_id> and
#     AWS_SECRET_ACCESS_KEY=<spaces_secret_key> before running `terraform init`.
# ---------------------------------------------------------------------------
# terraform {
#   backend "s3" {
#     endpoint                    = "https://nyc3.digitaloceanspaces.com"
#     bucket                      = "agentswarm-tfstate"
#     key                         = "agentswarm/prod/terraform.tfstate"
#     region                      = "us-east-1"  # required by the S3 protocol, value ignored by DO
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     force_path_style            = true
#   }
# }
