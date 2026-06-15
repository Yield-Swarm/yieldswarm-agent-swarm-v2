# Policy: ci-deploy
# Read-only access for CI/CD pipelines deploying infrastructure and containers.
# Assign to: the "ci-deploy" AppRole role.
# Scoped to the minimum credentials a pipeline needs to build and push images.

# Azure credentials — needed to push images to Azure Container Registry
# and to deploy Container Apps
path "secret/data/agentswarm/cloud/azure" {
  capabilities = ["read"]
}

# DigitalOcean credentials — needed to push to DO Container Registry
# and deploy Droplets/Apps
path "secret/data/agentswarm/cloud/digitalocean" {
  capabilities = ["read"]
}

# GitHub token — needed for GHCR image pushes and repo operations
path "secret/data/agentswarm/integrations" {
  capabilities = ["read"]
}

# Token self-renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
