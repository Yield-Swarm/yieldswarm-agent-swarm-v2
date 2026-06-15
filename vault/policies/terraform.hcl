# Policy: terraform
# Read-only access to cloud provider credentials and RPC/integration secrets.
# Assign to: the "terraform" AppRole role.
# Principle of least privilege — Terraform cannot write secrets or manage policies.

# Azure cloud credentials
path "secret/data/agentswarm/cloud/azure" {
  capabilities = ["read"]
}

# RunPod credentials
path "secret/data/agentswarm/cloud/runpod" {
  capabilities = ["read"]
}

# Vultr credentials
path "secret/data/agentswarm/cloud/vultr" {
  capabilities = ["read"]
}

# DigitalOcean credentials
path "secret/data/agentswarm/cloud/digitalocean" {
  capabilities = ["read"]
}

# Blockchain RPC endpoints and keys
path "secret/data/agentswarm/rpc" {
  capabilities = ["read"]
}

# Integration tokens required during infra provisioning
# (e.g. GitHub token for container registry, Vercel for edge deployment)
path "secret/data/agentswarm/integrations" {
  capabilities = ["read"]
}

# List available secret paths (metadata only — no secret values)
path "secret/metadata/agentswarm/cloud/*" {
  capabilities = ["list", "read"]
}

path "secret/metadata/agentswarm/rpc" {
  capabilities = ["list", "read"]
}

path "secret/metadata/agentswarm/integrations" {
  capabilities = ["list", "read"]
}

# Token self-renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
