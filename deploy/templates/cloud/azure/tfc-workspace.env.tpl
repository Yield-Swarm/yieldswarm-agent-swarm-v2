# Azure VMSS fallback — points at modular TFC workspace (PR #3 pattern)
# Full Terraform: deploy/terraform-tfc/
# Apply: make tfc-init && make tfc-apply

organization: ${TF_CLOUD_ORGANIZATION}
workspace: ${TF_WORKSPACE}

azure:
  subscription_id: ${AZURE_SUBSCRIPTION_ID}
  tenant_id: ${AZURE_TENANT_ID}
  client_id: ${AZURE_CLIENT_ID}
  resource_group: ${AZURE_RESOURCE_GROUP_NAME:-yieldswarm-fallback-rg}
  location: ${AZURE_LOCATION:-eastus}
  enable_fallback: ${ENABLE_AZURE_FALLBACK:-true}

akash:
  node: ${AKASH_NODE}
  chain_id: ${AKASH_CHAIN_ID}
  gpu_model_hint: ${AKASH_GPU_MODEL:-rtx4090}
