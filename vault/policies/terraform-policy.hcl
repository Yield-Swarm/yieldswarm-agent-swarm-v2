# Terraform CI/CD read-only access to cloud provider and RPC secrets.
# Bound to AppRole: yieldswarm-terraform

path "yieldswarm/data/azure" {
  capabilities = ["read"]
}

path "yieldswarm/data/runpod" {
  capabilities = ["read"]
}

path "yieldswarm/data/vultr" {
  capabilities = ["read"]
}

path "yieldswarm/data/digitalocean" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc" {
  capabilities = ["read"]
}

path "yieldswarm/data/agents/*" {
  capabilities = ["read"]
}

# Allow metadata reads for version pinning during rotation.
path "yieldswarm/metadata/azure" {
  capabilities = ["read", "list"]
}

path "yieldswarm/metadata/runpod" {
  capabilities = ["read", "list"]
}

path "yieldswarm/metadata/vultr" {
  capabilities = ["read", "list"]
}

path "yieldswarm/metadata/digitalocean" {
  capabilities = ["read", "list"]
}

path "yieldswarm/metadata/rpc" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
