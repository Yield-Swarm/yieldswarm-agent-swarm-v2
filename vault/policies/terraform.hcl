# Terraform CI/CD policy — read-only access to cloud provider and RPC secrets.

path "secret/data/yieldswarm/azure/credentials" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/azure/credentials" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/runpod/api" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/runpod/api" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/vultr/api" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/vultr/api" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/digitalocean/api" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/digitalocean/api" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/rpc/solana" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/rpc/solana" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/rpc/failover" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/rpc/failover" {
  capabilities = ["read", "list"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
