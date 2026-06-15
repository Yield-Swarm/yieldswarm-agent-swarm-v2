# Helixchain Multi-Cloud Fallback Terraform

This stack deploys Helixchain production compute to **Azure VMSS**, **GCP MIG**, **RunPod**, and **Vultr** using reusable modules and a single orchestration root.

## Terraform Cloud workspace: `Helixchainprod`

`backend.tf` is preconfigured to use the Terraform Cloud workspace named `Helixchainprod`.

Initialize with your Terraform Cloud organization:

```bash
cd infra/terraform
terraform init -backend-config="organization=<YOUR_TFC_ORG>"
```

If your Terraform Cloud token is not set locally:

```bash
export TF_TOKEN_app_terraform_io="<TFC_USER_OR_TEAM_TOKEN>"
```

## Deployment behavior

- `active_clouds` sets fallback priority (first value is primary).
- `deploy_all_targets=true` deploys all listed clouds in parallel (hot fallback).
- `deploy_all_targets=false` deploys only the primary cloud (cold fallback promotion model).

## Quick start

1. Copy example variables and fill provider-specific values.
2. Store secrets in Terraform Cloud workspace variables for `Helixchainprod`.
3. Run plan/apply.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Required secret variables in Terraform Cloud

- `azure_client_secret`
- `gcp_credentials_json`
- `runpod_api_key`
- `vultr_api_key`

You can also use provider-native environment variables (ARM_*, GOOGLE_*, RUNPOD_API_KEY, VULTR_API_KEY).

## Packer integration

Image variables in this Terraform stack (`azure_image_id`, `gcp_image`, and optional `vultr_image_id`) are intended to consume outputs from the templates in `../packer`.
