# Least-privilege policy for Terraform CI/CD.
# Read-only access to cloud provider and RPC secret paths.

path "auth/approle/login" {
  capabilities = ["create", "update"]
}

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

path "yieldswarm/data/akash" {
  capabilities = ["read"]
}

# Allow Terraform to validate connectivity during plan/apply.
path "sys/health" {
  capabilities = ["read", "sudo"]
}
