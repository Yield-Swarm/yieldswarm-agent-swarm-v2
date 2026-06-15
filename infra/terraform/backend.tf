###############################################################################
# HCP Terraform (Terraform Cloud) integration.
#
# The root module is wired to the "Helixchainprod" workspace. The organization
# is intentionally NOT hard-coded so the same configuration can be promoted
# across orgs; supply it via the TF_CLOUD_ORGANIZATION environment variable:
#
#   export TF_CLOUD_ORGANIZATION="helixchain"
#   export TF_TOKEN_app_terraform_io="<hcp-terraform-api-token>"
#   terraform init
#   terraform apply
#
# For a purely local run (no HCP backend), initialise with the backend disabled:
#
#   terraform init -backend=false   # validate / plan only, no remote state
#
# or comment out the `cloud` block below and Terraform will use local state.
###############################################################################

terraform {
  cloud {
    # organization is read from TF_CLOUD_ORGANIZATION
    workspaces {
      name = "Helixchainprod"
    }
  }
}
