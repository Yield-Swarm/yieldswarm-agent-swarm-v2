# Runtime policy for Akash deployments and Vault Agent sidecars.
# Read-only access to secrets required by agents at container start.

path "auth/approle/login" {
  capabilities = ["create", "update"]
}

path "yieldswarm/data/akash" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc" {
  capabilities = ["read"]
}

path "yieldswarm/data/runpod" {
  capabilities = ["read"]
}

path "yieldswarm/data/digitalocean" {
  capabilities = ["read"]
}

path "yieldswarm/data/vultr" {
  capabilities = ["read"]
}

path "sys/health" {
  capabilities = ["read"]
}
