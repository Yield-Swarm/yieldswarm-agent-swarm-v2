# Akash container runtime read-only access.
# Includes operational secrets needed by agents at startup; excludes Terraform-only paths.

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

path "yieldswarm/data/agents" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
