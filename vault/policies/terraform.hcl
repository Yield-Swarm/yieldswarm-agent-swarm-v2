# vault/policies/terraform.hcl
# Least-privilege read access for the Terraform AppRole.
# Grants read-only access to cloud provider credentials and RPC secrets
# so Terraform can authenticate to Azure, RunPod, Vultr, DigitalOcean,
# and configure RPC endpoints — without write or delete ability.
#
# Apply:
#   vault policy write terraform vault/policies/terraform.hcl

# Azure service principal credentials
path "secret/data/azure/credentials" {
  capabilities = ["read"]
}

path "secret/metadata/azure/credentials" {
  capabilities = ["read", "list"]
}

# RunPod API credentials
path "secret/data/runpod/credentials" {
  capabilities = ["read"]
}

path "secret/metadata/runpod/credentials" {
  capabilities = ["read", "list"]
}

# Vultr API credentials
path "secret/data/vultr/credentials" {
  capabilities = ["read"]
}

path "secret/metadata/vultr/credentials" {
  capabilities = ["read", "list"]
}

# DigitalOcean API credentials
path "secret/data/digitalocean/credentials" {
  capabilities = ["read"]
}

path "secret/metadata/digitalocean/credentials" {
  capabilities = ["read", "list"]
}

# RPC endpoint secrets (Solana, EVM, etc.)
path "secret/data/rpc/*" {
  capabilities = ["read"]
}

path "secret/metadata/rpc/*" {
  capabilities = ["read", "list"]
}

# Terraform backend state (if using Vault as state backend — optional)
path "secret/data/terraform/state/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/terraform/state/*" {
  capabilities = ["read", "list", "delete"]
}

# Allow Terraform to look up its own AppRole token TTL
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
