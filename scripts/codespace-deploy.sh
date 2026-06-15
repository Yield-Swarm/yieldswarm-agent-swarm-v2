#!/usr/bin/env bash
set -euo pipefail

cp -n .env.example .env || true
cp -n terraform.tfvars.example terraform.tfvars || true

echo "Step 1/3: Akash lease deployment"
bash ./scripts/akash-deploy.sh

echo "Step 2/3: Terraform init"
terraform init

echo "Step 3/3: Terraform apply"
terraform apply -var-file=terraform.tfvars
